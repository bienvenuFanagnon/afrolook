import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/chronique/chroniquehome.dart';
import 'package:afrotok/pages/chronique/chroniquedetails.dart';

import '../../chronique/chroniqueform.dart';

class ChroniqueSectionComponent extends StatelessWidget {
  final Map<String, String> videoThumbnails;
  final Map<String, bool> userVerificationStatus;
  final Map<String, UserData> userDataCache;
  final bool isLoadingChroniques;
  final Map<String, List<Chronique>> groupedChroniques;

  const ChroniqueSectionComponent({
    Key? key,
    required this.videoThumbnails,
    required this.userVerificationStatus,
    required this.userDataCache,
    required this.isLoadingChroniques,
    required this.groupedChroniques,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoadingChroniques) {
      return _buildChroniquesShimmer();
    }

    if (groupedChroniques.isEmpty) {
      return SizedBox();
    }

    final groupedList = groupedChroniques.values.toList();
    groupedList.sort((a, b) {
      final latestA = a.isNotEmpty ? a.first.createdAt : Timestamp.now();
      final latestB = b.isNotEmpty ? b.first.createdAt : Timestamp.now();
      return latestB.compareTo(latestA);
    });

    return Container(
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context),
          _buildChroniquesList(groupedList),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Chroniques Actives',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context!,
                MaterialPageRoute(
                  builder: (context) => ChroniqueHomePage(),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Color(0xFFFFD700).withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Color(0xFFFFD700)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Voir tout',
                    style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    color: Color(0xFFFFD700),
                    size: 12,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChroniquesList(List<List<Chronique>> groupedList) {
    return Expanded(
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12),
        itemCount: groupedList.length,
        itemBuilder: (context, index) {
          return _buildChroniqueItem(groupedList[index],context);
        },
      ),
    );
  }

  Widget _buildChroniqueItem(List<Chronique> userChroniques,BuildContext context) {
    if (userChroniques.isEmpty) return SizedBox();

    final firstChronique = userChroniques.first;
    final chroniqueCount = userChroniques.length;
    final hasMultiple = chroniqueCount > 1;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context!,
          MaterialPageRoute(
            builder: (context) => ChroniqueDetailPage(
              userChroniques: userChroniques,
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: EdgeInsets.only(right: 8),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 140,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFFFFD700),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: Offset(2, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildChroniquePreview(firstChronique),
                  ),
                ),
                if (_isUserVerified(firstChronique.userId))
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 3,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.verified,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                if (hasMultiple)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Color(0xFFFFD700)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 3,
                            offset: Offset(1, 1),
                          ),
                        ],
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
                Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_red_eye, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          _formatCount(firstChronique.viewCount),
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
            ),
            SizedBox(height: 6),
            Container(
              constraints: BoxConstraints(maxWidth: 130),
              child: Text(
                '@${firstChronique.userPseudo}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChroniquePreview(Chronique chronique) {
    switch (chronique.type) {
      case ChroniqueType.TEXT:
        return Container(
          decoration: BoxDecoration(
            color: Color(int.parse(chronique.backgroundColor!, radix: 16)),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                chronique.textContent ?? '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFD700),
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[800],
                child: Icon(
                  Icons.error,
                  color: Color(0xFFFFD700),
                  size: 30,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
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
            if (videoThumbnails.containsKey(chronique.id!))
              Image.file(
                File(videoThumbnails[chronique.id!]!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            else
              Container(
                color: Colors.grey[900],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_filled,
                        color: Color(0xFFFFD700),
                        size: 30,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Vidéo',
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
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  bool _isUserVerified(String userId) {
    return userVerificationStatus[userId] ?? false;
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  Widget _buildChroniquesShimmer() {
    return Container(
      height: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    width: 120,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    width: 60,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  width: 80,
                  margin: EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey[800]!,
                        highlightColor: Colors.grey[700]!,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[800]!,
                        highlightColor: Colors.grey[700]!,
                        child: Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
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

// Clé de navigation globale si nécessaire
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();