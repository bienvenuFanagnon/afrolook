import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/model_data.dart';
import '../../services/challengeMonh/challenge_month_service.dart';
import '../postDetails.dart';
import '../postDetailsVideo.dart';
import 'challenge_month_page.dart';

void showChallengeMonthAnnounceModal(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD600).withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD600).withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône trophée
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD600).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFFFD600),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '🏆 CHALLENGE DU MOIS !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFFD600),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Chaque mois, le post avec le meilleur score remporte un prix (ex: +5 000 FCFA à +73 000 FCFA) ! Découvrez les meilleurs posts du moment :',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<Post>>(
                  future: _fetchTop3PostsWithCreators(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: SizedBox(
                          height: 150,
                          child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD600))),
                        ),
                      );
                    }
                    if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final posts = snapshot.data!;
                    return SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: posts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final post = posts[index];
                          return _buildPostCard(context, post, index + 1);
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: Text(
                          'PLUS TARD',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const ChallengeMonthPage()));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD600),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('VOIR LE CLASSEMENT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Récupère les 3 meilleurs posts et charge les créateurs (utilisateur ou canal)
Future<List<Post>> _fetchTop3PostsWithCreators() async {
  try {
    final service = ChallengeMonthService();
    final now = DateTime.now();
    final posts = await service.getTopPostsForMonth(now, limit: 3);

    return posts;
  } catch (e) {
    print('Erreur chargement top posts challenge: $e');
    return [];
  }
}


Widget _buildPostCard(BuildContext context, Post post, int rank) {
  final isVideo = post.dataType == PostDataType.VIDEO.name;
  final isText = post.dataType == PostDataType.TEXT.name;
  final imageUrl = (post.images?.isNotEmpty ?? false)
      ? post.images!.first
      : (post.thumbnail ?? '');
  final displayName = post.canal?.titre ?? (post.user?.pseudo ?? '');
  final totalScore = (post.totalInteractions ?? 0) +
      (post.loves ?? 0) +
      (post.favoritesCount ?? 0) +
      (post.uniqueViewsCount ?? 0);

  // Pour les posts texte, on extrait les 20 premiers caractères
  String? previewText;
  if (isText && post.description != null && post.description!.isNotEmpty) {
    previewText = post.description!.length > 20
        ? '${post.description!.substring(0, 20)}...'
        : post.description;
  }

  return GestureDetector(
    onTap: () {
      Navigator.pop(context);
      if (isVideo) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => VideoYoutubePageDetails(initialPost: post)));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsPost(post: post)));
      }
    },
    child: Container(
      width: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Image ou fallback avec aperçu texte
            if (imageUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallbackImageWithText(isText, previewText)),
              )
            else
              Positioned.fill(child: _fallbackImageWithText(isText, previewText)),
            // Badge rang
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: rank == 1 ? const Color(0xFFFFD600) : Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    color: rank == 1 ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            // Overlay infos
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.bar_chart, color: Color(0xFFFFD600), size: 10),
                        const SizedBox(width: 2),
                        Text(_formatScore(totalScore), style: const TextStyle(color: Colors.white70, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _fallbackImageWithText(bool isText, String? previewText) {
  return Container(
    color: Colors.grey[800],
    child: Center(
      child: isText && previewText != null
          ? Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          previewText,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      )
          : const Icon(Icons.image, color: Colors.grey, size: 30),
    ),
  );
}

String _formatScore(int score) {
  if (score < 1000) return score.toString();
  if (score < 1000000) return '${(score / 1000).toStringAsFixed(1)}K';
  return '${(score / 1000000).toStringAsFixed(1)}M';
}