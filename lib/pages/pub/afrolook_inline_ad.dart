import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/utils/abonnement_utils.dart';
import '../user/userAbonnementPage.dart';
import '../postDetails.dart';
import '../post_video_format_tel_details.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

/// Bannière pub inline affichant un post pub Afrolook (interne).
/// Masquée pour Premium, Gold et Admin.
/// Utilise les pubs préchargées depuis authProvider.advertisements.
class AfrolookInlineAd extends StatefulWidget {
  const AfrolookInlineAd({Key? key}) : super(key: key);

  @override
  State<AfrolookInlineAd> createState() => _AfrolookInlineAdState();
}

class _AfrolookInlineAdState extends State<AfrolookInlineAd> {
  Map<String, dynamic>? _adData;
  String? _lastAdId;
  bool _viewRecorded = false;
  Timer? _rotationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickAd();
      // Rotation toutes les 30s pour éviter toujours la même pub
      _rotationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        _pickAd(rotate: true);
      });
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  void _pickAd({bool rotate = false}) {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final ads = auth.advertisements;
    if (ads.isEmpty) return;

    Map<String, dynamic> picked;
    if (ads.length == 1) {
      picked = ads.first;
    } else {
      // Éviter de re-choisir la même pub (sauf si une seule disponible)
      List<Map<String, dynamic>> candidates = ads.where((a) {
        final adId = (a['ad'] as Map<String, dynamic>?)?['id'];
        return adId != _lastAdId;
      }).toList();
      if (candidates.isEmpty) candidates = ads;
      candidates.shuffle(Random());
      picked = candidates.first;
    }

    final newId = (picked['ad'] as Map<String, dynamic>?)?['id'];
    if (!rotate && newId == _lastAdId) return;

    _lastAdId = newId;
    _viewRecorded = false;
    if (mounted) setState(() => _adData = picked);
    _recordView(picked);
  }

  Future<void> _recordView(Map<String, dynamic> adData) async {
    if (_viewRecorded) return;
    _viewRecorded = true;
    try {
      final ad = Advertisement.fromJson(adData['ad'] as Map<String, dynamic>);
      if (ad.id == null) return;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final ref = FirebaseFirestore.instance.collection('Advertisements').doc(ad.id);
      await ref.update({
        'views': FieldValue.increment(1),
        'dailyStats.$today': FieldValue.increment(1),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });
      final doc = await ref.get();
      if (doc.exists) {
        final viewers = List<String>.from(doc.data()?['viewersIds'] ?? []);
        if (!viewers.contains(uid)) {
          await ref.update({
            'uniqueViews': FieldValue.increment(1),
            'viewersIds': FieldValue.arrayUnion([uid]),
          });
        }
      }
    } catch (e) {
      printVm('AfrolookInlineAd._recordView error: $e');
    }
  }

  Future<void> _recordClick(Advertisement ad) async {
    if (ad.id == null) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final ref = FirebaseFirestore.instance.collection('Advertisements').doc(ad.id);
      await ref.update({
        'clicks': FieldValue.increment(1),
        'dailyStats.$today.clicks': FieldValue.increment(1),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });
      final doc = await ref.get();
      if (doc.exists) {
        final clickers = List<String>.from(doc.data()?['clickersIds'] ?? []);
        if (!clickers.contains(uid)) {
          await ref.update({
            'uniqueClicks': FieldValue.increment(1),
            'clickersIds': FieldValue.arrayUnion([uid]),
          });
        }
      }
    } catch (e) {
      printVm('AfrolookInlineAd._recordClick error: $e');
    }
  }

  void _openPostPage(BuildContext context, Post post, Advertisement ad) {
    _recordClick(ad);
    if (post.dataType == PostDataType.VIDEO.name ||
        (post.url_media?.contains('.mp4') ?? false) ||
        (post.url_media?.contains('.mov') ?? false)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailsVideoFormatTel(initialPost: post, isIn: false),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailsPost(post: post)),
      );
    }
  }

  String? _thumbUrl(Post post) {
    if (post.thumbnail?.isNotEmpty == true) return post.thumbnail;
    final firstImg = post.images?.isNotEmpty == true ? post.images!.first : null;
    if (firstImg?.isNotEmpty == true) return firstImg;
    if (post.dataType != 'VIDEO' && post.url_media?.isNotEmpty == true) return post.url_media;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final abonnement = auth.loginUserData.abonnement;
    final role = auth.loginUserData.role;

    if (AbonnementUtils.isPremiumActive(abonnement) || AbonnementUtils.isAdmin(role)) {
      return const SizedBox.shrink();
    }

    if (_adData == null) return const SizedBox.shrink();

    final post = Post.fromJson(_adData!['post'] as Map<String, dynamic>);
    final ad = Advertisement.fromJson(_adData!['ad'] as Map<String, dynamic>);
    final thumb = _thumbUrl(post);
    final caption = post.description ?? '';
    final btnText = ad.actionButtonText ?? 'En savoir plus';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : const Color(0xFF111111);
    final subText = isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _openPostPage(context, post, ad),
          child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header sponsorisé
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Sponsorisé',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            decoration: TextDecoration.none),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.info_outline, size: 14, color: subText),
                  ],
                ),
              ),
              // Contenu
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    if (thumb != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: thumb,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              width: 72,
                              height: 72,
                              color: isDark ? Colors.white10 : Colors.black12),
                          errorWidget: (_, __, ___) => Container(
                              width: 72,
                              height: 72,
                              color: isDark ? Colors.white10 : Colors.black12,
                              child: Icon(Icons.image, color: subText)),
                        ),
                      ),
                    if (thumb != null) const SizedBox(width: 10),
                    // Texte
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (caption.isNotEmpty)
                            Text(
                              caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: textColor,
                                height: 1.3,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () async {
                              await _recordClick(ad);
                              final url = ad.actionUrl;
                              if (url != null && url.isNotEmpty) {
                                final uri = Uri.tryParse(url);
                                if (uri != null && await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode: LaunchMode.externalApplication);
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                btnText,
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    decoration: TextDecoration.none),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        ), // GestureDetector card
        // CTA abonnement
        GestureDetector(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => AbonnementScreen())),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF416C)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium, color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text(
                  'Ne plus voir de pubs → Premium',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
