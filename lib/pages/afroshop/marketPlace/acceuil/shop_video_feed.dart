import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../../constant/custom_theme.dart';
import '../../../../models/model_data.dart';
import '../../../user/conponent.dart';
import '../../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../../providers/authProvider.dart';
import '../shop_product_comments.dart';
import 'produit_details.dart';

class ShopVideoFeed extends StatefulWidget {
  final List<ArticleData> articles;
  final VoidCallback? onLoadMore;

  const ShopVideoFeed({Key? key, required this.articles, this.onLoadMore})
      : super(key: key);

  @override
  State<ShopVideoFeed> createState() => _ShopVideoFeedState();
}

class _ShopVideoFeedState extends State<ShopVideoFeed> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    if (widget.articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded, size: 64, color: Colors.grey[400]),
            SizedBox(height: 12),
            Text(
              'Aucun produit à afficher',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.articles.length,
      onPageChanged: (i) {
        setState(() => _currentIndex = i);
        if (i >= widget.articles.length - 2) {
          widget.onLoadMore?.call();
        }
      },
      itemBuilder: (ctx, i) {
        return _ShopVideoItem(
          key: ValueKey(widget.articles[i].id),
          article: widget.articles[i],
          isActive: i == _currentIndex,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item individuel du feed
// ─────────────────────────────────────────────────────────────────────────────

class _ShopVideoItem extends StatefulWidget {
  final ArticleData article;
  final bool isActive;

  const _ShopVideoItem({Key? key, required this.article, required this.isActive})
      : super(key: key);

  @override
  State<_ShopVideoItem> createState() => _ShopVideoItemState();
}

class _ShopVideoItemState extends State<_ShopVideoItem> {
  VideoPlayerController? _controller;
  bool _isMuted = true;
  bool _isLiked = false;
  bool _likeLoading = false;

  late UserAuthProvider _authProvider;
  late CategorieProduitProvider _catalogProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _catalogProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isActive && widget.article.videoUrl != null) {
      _initVideo();
    }
  }

  @override
  void didUpdateWidget(covariant _ShopVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      if (widget.article.videoUrl != null) _initVideo();
    } else if (!widget.isActive && oldWidget.isActive) {
      _disposeVideo();
    }
  }

  Future<void> _initVideo() async {
    if (_controller != null) return;
    final url = widget.article.videoUrl!;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await ctrl.initialize();
      ctrl.setLooping(true);
      ctrl.setVolume(0);
      if (mounted) {
        setState(() => _controller = ctrl);
        ctrl.play();
      } else {
        ctrl.dispose();
      }
    } catch (e) {
      ctrl.dispose();
    }
  }

  void _disposeVideo() {
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() => _isMuted = !_isMuted);
    _controller!.setVolume(_isMuted ? 0 : 1);
  }

  Future<void> _handleLike() async {
    if (_likeLoading) return;
    setState(() { _likeLoading = true; _isLiked = !_isLiked; });
    try {
      await _catalogProvider.getArticleById(widget.article.id!).then((list) async {
        if (list.isNotEmpty) {
          final a = list.first;
          a.jaime = (a.jaime ?? 0) + (_isLiked ? 1 : -1);
          widget.article.jaime = a.jaime;
          await _catalogProvider.updateArticle(a, context);
        }
      });
    } catch (_) {
      setState(() => _isLiked = !_isLiked);
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShopProductComments(articleId: widget.article.id!),
    );
  }

  void _openDetails() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ProduitDetail(productId: widget.article.id!),
    ));
  }

  Future<void> _share() async {
    final title = widget.article.titre ?? 'Produit Afrolook';
    await Share.share('$title — Voir sur Afrolook');
    try {
      await FirebaseFirestore.instance
          .collection('Articles')
          .doc(widget.article.id)
          .update({'partage': FieldValue.increment(1)});
    } catch (_) {}
  }

  String _formatCount(int? n) {
    if (n == null || n == 0) return '0';
    if (n < 1000) return '$n';
    if (n < 1000000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '${(n / 1000000).toStringAsFixed(1)}M';
  }

  String _formatDuration(int? sec) {
    if (sec == null) return '';
    return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final article = widget.article;
    final coverUrl = article.thumbnailUrl ??
        (article.images?.isNotEmpty == true ? article.images!.first : '');
    final hasVideo = article.videoUrl != null;

    return GestureDetector(
      onTap: _toggleMute,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Fond : vidéo ou image ──────────────────────────────────────
            if (hasVideo && _controller != null && _controller!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: Colors.grey[900],
                  child: Icon(Icons.shopping_bag_rounded, color: Colors.grey[700], size: 80),
                ),
              ),

            // ── Dégradé bas ────────────────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                  ),
                ),
              ),
            ),

            // ── Indicateur chargement vidéo ────────────────────────────────
            if (hasVideo && _controller == null)
              Center(child: CircularProgressIndicator(color: CustomConstants.kPrimaryColor)),

            // ── Badge muet ────────────────────────────────────────────────
            if (hasVideo)
              Positioned(
                top: 16, right: 16,
                child: GestureDetector(
                  onTap: _toggleMute,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),

            // ── Actions droite ─────────────────────────────────────────────
            Positioned(
              right: 12,
              bottom: 140,
              child: Column(
                children: [
                  _ActionBtn(
                    icon: _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: _isLiked ? Colors.red : Colors.white,
                    label: _formatCount(article.jaime),
                    onTap: _handleLike,
                    loading: _likeLoading,
                  ),
                  SizedBox(height: 20),
                  _ActionBtn(
                    icon: Icons.comment_rounded,
                    color: Colors.white,
                    label: _formatCount(article.commentaires),
                    onTap: _openComments,
                  ),
                  SizedBox(height: 20),
                  _ActionBtn(
                    icon: Icons.share_rounded,
                    color: Colors.white,
                    label: _formatCount(article.partage),
                    onTap: _share,
                  ),
                  SizedBox(height: 20),
                  _ActionBtn(
                    icon: Icons.shopping_bag_rounded,
                    color: CustomConstants.kPrimaryColor,
                    label: 'Voir',
                    onTap: _openDetails,
                  ),
                ],
              ),
            ),

            // ── Info produit bas ───────────────────────────────────────────
            Positioned(
              left: 16, right: 80, bottom: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vendeur
                  if (article.user != null)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey[800],
                          backgroundImage: (article.user!.imageUrl?.isNotEmpty == true)
                              ? CachedNetworkImageProvider(article.user!.imageUrl!)
                              : null,
                          child: (article.user!.imageUrl?.isEmpty != false)
                              ? Icon(Icons.person, color: Colors.white, size: 18)
                              : null,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '@${article.user!.pseudo ?? ''}',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  SizedBox(height: 8),

                  // Titre
                  Text(
                    article.titre ?? 'Produit',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),

                  // Prix + drapeau pays
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: CustomConstants.kPrimaryColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${article.prix ?? 0} FCFA',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            countryFlag(article.countryData?['countryCode'] ?? 'TG', size: 16),
                            if ((article.countryData?['country'] ?? '').isNotEmpty) ...[
                              SizedBox(width: 5),
                              Text(
                                article.countryData!['country']!,
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),

                  // Hashtags
                  if (article.hashTags?.isNotEmpty == true)
                    Wrap(
                      spacing: 6,
                      children: article.hashTags!
                          .take(4)
                          .map((t) => Text('#$t',
                              style: TextStyle(color: CustomConstants.kPrimaryColor, fontSize: 12)))
                          .toList(),
                    ),

                  // Durée vidéo si présente
                  if (hasVideo && article.videoDurationSec != null) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 14),
                        SizedBox(width: 4),
                        Text(
                          _formatDuration(article.videoDurationSec),
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Bouton Contacter ───────────────────────────────────────────
            Positioned(
              left: 16, right: 80, bottom: 28,
              child: ElevatedButton.icon(
                onPressed: _openDetails,
                icon: Icon(Icons.phone_rounded, size: 16, color: Colors.white),
                label: Text('Contacter le vendeur', style: TextStyle(color: Colors.white, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomConstants.kPrimaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton action réutilisable
// ─────────────────────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool loading;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          if (loading)
            SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(icon, color: color, size: 30, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}
