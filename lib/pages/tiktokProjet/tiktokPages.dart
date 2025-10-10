import 'package:afrotok/pages/user/monetisation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tiktok_scraper/tiktok_scraper.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'newTikTokVideo.dart';
String pubTex = " 🚀 Gagnez jusqu'à 1 Publicash (25 FCFA) par vue ➡️ 👀 Regardez, 💬 Commentez et 👍 Likez les vidéos TikTok pour soutenir vos créateurs préférés ! 💰 ";
class VideoModel {
  final String id;
  final String videoUrl;
  // final String tiktokUsername;
  // final String tiktokProfileUrl;
  final String userId;
  final DateTime timestamp;
  final int durationDays;
  final int clickCount;
  final List<String> viewers;

  VideoModel({
    required this.id,
    required this.videoUrl,
    // required this.tiktokUsername,
    // required this.tiktokProfileUrl,
    required this.userId,
    required this.timestamp,
    required this.durationDays,
    required this.clickCount,
    required this.viewers,
  });

  factory VideoModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoModel(
      id: doc.id,
      videoUrl: data['videoUrl'],
      // tiktokUsername: data['tiktokUsername'],
      // tiktokProfileUrl: data['tiktokProfileUrl'],
      userId: data['userId'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      durationDays: data['durationDays'] ?? 2,
      clickCount: data['clickCount'] ?? 0,
      // viewers:data['viewers']?? [],

      viewers: List<String>.from(data['viewers'] ?? []), // 👈 casting sécurisé

    );
  }
}
class VideoFeedTiktokPage extends StatelessWidget {
  final bool fullPage;
  VideoFeedTiktokPage({ required this.fullPage});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        automaticallyImplyLeading: fullPage,
        iconTheme: IconThemeData(color: Colors.red),

        title: Text('TikTok',style: TextStyle(color: Colors.red,fontWeight: FontWeight.w900),),
        actions: [TextButton(onPressed: () {
          // Get.to(VideoFeedTiktokPage(fullPage: true,));
          Navigator.push(context,MaterialPageRoute(builder: (context) => VideoFeedTiktokPage(fullPage: true,),) );
        }, child: Text('Voir plus',style: TextStyle(color: Colors.red,fontWeight: FontWeight.w900),))],
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0),
            child: Container(
              height: 20, // Hauteur fixe pour le message
              child: Marquee(
                text: pubTex,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold
                ),
                blankSpace: 20.0,
                velocity: 50.0,
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('videosTiktok')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final videos = snapshot.data!.docs
                    .map((doc) => VideoModel.fromDocument(doc))
                    .where((video) => video.timestamp.add(Duration(days: video.durationDays)).isAfter(DateTime.now()))
                    .toList();

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 5,
                    crossAxisSpacing: 5,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return FutureBuilder<TiktokVideo>(
                      future: TiktokScraper.getVideoInfo(video.videoUrl),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return _buildLoadingCard();
                        }

                        if (snapshot.hasError || !snapshot.hasData) {
                          return _buildErrorCard();
                        }

                        final tiktokVideo = snapshot.data!;
                        return _buildVideoCard(context, video, tiktokVideo);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.pink,

        onPressed:() {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UploadVideoPage()),
          );
        },
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, VideoModel video, TiktokVideo tiktokVideo) {
    late UserAuthProvider authProvider =
    Provider.of<UserAuthProvider>(context, listen: false);
    return GestureDetector(
      onTap: () {
       authProvider.checkAppVersionAndProceed(context, () {
          _handleVideoTap(context, video);
        });
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail

          // VideoFeed2TiktokPage(videoUrl: video.videoUrl),
          Image.network(
            tiktokVideo.thumbnail,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.grey[900]),
          ),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87],
              ),
            ),
          ),

          // Author info
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(tiktokVideo.author.avatar),
                      radius: 15,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '@${tiktokVideo.author.username}',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  '${_formatNumber(tiktokVideo.author.followerCount as int)} abonnés',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          // Click count
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.remove_red_eye, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '${video.clickCount}',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

          // Admin delete button
          if (authProvider.loginUserData.role == UserRole.ADM.name)
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDelete(context, video.id),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleVideoTiktok(BuildContext context, VideoModel video) async {
    try {
      // Update click count
      // await FirebaseFirestore.instance
      //     .collection('videosTiktok')
      //     .doc(video.id)
      //     .update({'clickCount': video.clickCount + 1});
      print('Video link: ${video.id}');
      print('videoUrl link: ${video.videoUrl}');

      // Try to open TikTok app first
      final appUrl = 'tiktok://v/${video.id}';
      print('Video link2: ${Uri.parse(appUrl)}');
      // if (await canLaunchUrl(Uri.parse(appUrl))) {
      //   await launchUrl(Uri.parse(appUrl));
      //   return;
      // }

      // Fallback to web URL
      await launchUrl(
        Uri.parse(video.videoUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir TikTok: ${e.toString()}')),
      );
    }
  }

  Future<void> _handleVideoTap(BuildContext context, VideoModel video) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      // final videoDoc = await FirebaseFirestore.instance
      //     .collection('videosTiktok')
      //     .doc(video.id)
      //     .get();
      //
      // final userData = UserData.fromJson(userDoc.data()!);
      final hasViewed =
          video.viewers.contains(user.uid);

      // Mettre à jour le compteur de clics
      await FirebaseFirestore.instance
          .collection('videosTiktok')
          .doc(video.id)
          .update({
        'clickCount': video.clickCount + 1,
        'viewers': FieldValue.arrayUnion([user.uid])
      });

      if (!hasViewed) {
        // Ajouter la récompense
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .update({
          'tiktokviewerSolde': FieldValue.increment(0.5),
          'viewedVideos': FieldValue.arrayUnion([video.id])
        });
        // _handleVideoTiktok(context, video);

        // Afficher le modal de récompense
        _showRewardModal(context);
      } else {
        // _handleVideoTiktok(context, video);

// Avertir que la vidéo a déjà été vue
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info, color: Colors.pink, size: 40),
                  SizedBox(height: 16),
                  Text(
                    'Vous avez déjà reçu votre récompense pour cette vidéo',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK', style: TextStyle(color: Colors.pink)),
                ),
              ],
            );
          },
        );

        // Avertir que la vidéo a déjà été vue
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Center(
        //       child: Column(
        //         children: [
        //           Icon(Icons.info, color: Colors.pink),
        //           // SizedBox(width: 10),
        //           Text('Vous avez déjà reçu votre récompense pour cette vidéo'),
        //         ],
        //       ),
        //     ),
        //     backgroundColor: Colors.grey[900],
        //   ),
        // );
      }
      _handleVideoTiktok(context, video);

      // Ouvrir la vidéo
      // final appUrl = 'tiktok://v/${video.id}';
      // print('appurl : ${Uri.parse(appUrl)}');
      //
      // if (await canLaunchUrl(Uri.parse(appUrl))) {
      //   print('ici 1 : ${Uri.parse(appUrl)}');
      //   await launchUrl(Uri.parse(appUrl));
      // } else {
      //   print('ici 2 : ${Uri.parse(appUrl)}');
      //
      //   await launchUrl(Uri.parse(video.videoUrl),
      //       mode: LaunchMode.externalApplication);
      // }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  void _showRewardModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.pink, width: 2),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.celebration, size: 60, color: Colors.pink),
              SizedBox(height: 20),
              Text('Félicitations! 🎉',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('Vous avez gagné 0.5 Publicash',
                  style: TextStyle(color: Colors.grey)),
              Text('(1 PC équivaut à 25 F CFA)',
                  style: TextStyle(color: Colors.grey)),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Fermer',
                        style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => MonetisationPage()));
                    },
                    child: Row(
                      children: [
                        Icon(Icons.account_balance_wallet,color: Colors.white),
                        SizedBox(width: 10),
                        Text('Voir mon solde',style: TextStyle(color: Colors.white),),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toString();
  }

  Widget _buildLoadingCard() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(height: 8),
            Text(
              'Vidéo indisponible',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Supprimer la vidéo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('videosTiktok').doc(docId).delete();
              Navigator.pop(context);
            },
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

}



