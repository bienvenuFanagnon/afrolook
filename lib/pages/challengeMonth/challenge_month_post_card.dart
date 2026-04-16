// lib/pages/challenge/challenge_post_card.dart
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/model_data.dart';
import '../postDetails.dart';
import '../postDetailsVideo.dart';

class ChallengePostCard extends StatefulWidget {
  final Post post;
  final int rank;
  final bool isWinner;
  final VoidCallback? onPayout;

  const ChallengePostCard({
    Key? key,
    required this.post,
    required this.rank,
    this.isWinner = false,
    this.onPayout,
  }) : super(key: key);

  @override
  State<ChallengePostCard> createState() => _ChallengePostCardState();
}

class _ChallengePostCardState extends State<ChallengePostCard> {
  UserData? _user;
  Canal? _canal;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCreatorData();
  }

  Future<void> _loadCreatorData() async {
     printVm('Poste  challenge user: ${widget.post.user_id}');
     printVm('Poste  challenge canal: ${widget.post.canal_id}');
    if (widget.post.user != null) {
      _user = widget.post.user;
      return;
    }
    if (widget.post.canal != null) {
      _canal = widget.post.canal;
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (widget.post.canal_id != null && widget.post.canal_id!.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('Canaux')
            .doc(widget.post.canal_id)
            .get();
        if (doc.exists) {
          _canal = Canal.fromJson(doc.data() as Map<String, dynamic>);
          widget.post.canal = _canal;
        }
      } else if (widget.post.user_id != null && widget.post.user_id!.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(widget.post.user_id)
            .get();
        if (doc.exists) {
          _user = UserData.fromJson(doc.data() as Map<String, dynamic>);
          widget.post.user = _user;
        }
      }
    } catch (e) {
      print('Erreur chargement créateur: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _displayName {
    if (_canal != null) return '#${_canal!.titre}';
    if (_user != null) return '@${_user!.pseudo}';
    return 'Utilisateur';
  }

  String? get _avatarUrl {
    if (_canal != null) return _canal!.urlImage;
    if (_user != null) return _user!.imageUrl;
    return null;
  }

  int get _subscriberCount {
    if (_canal != null) return _canal!.usersSuiviId?.length ?? 0;
    if (_user != null) return _user!.userAbonnesIds?.length ?? 0;
    return 0;
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.post.dataType == PostDataType.VIDEO.name;
    final isAudio = widget.post.dataType == PostDataType.AUDIO.name;
    final isText = widget.post.dataType == PostDataType.TEXT.name;
    final hasImage = (widget.post.images?.isNotEmpty ?? false);
    final thumbnail = widget.post.thumbnail;
    final totalInteractions = widget.post.totalInteractions ?? 0;
    final likes = widget.post.loves ?? 0;
    final comments = widget.post.comments ?? 0;
    final favorites = widget.post.favoritesCount ?? 0;

    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD600))),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (isVideo) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => VideoYoutubePageDetails(initialPost: widget.post)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsPost(post: widget.post)));
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: widget.isWinner ? Border.all(color: const Color(0xFFFFD600), width: 2) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniature média + badge rang
            Stack(
              children: [
                // Contenu selon le type
                if (isVideo && (thumbnail != null && thumbnail.isNotEmpty))
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    child: Image.network(thumbnail, height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallbackContent(isVideo, isAudio, isText)),
                  )
                else if (hasImage)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: widget.post.images!.first,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _buildFallbackContent(isVideo, isAudio, isText),
                    ),
                  )
                else
                  _buildFallbackContent(isVideo, isAudio, isText),
                // Badge rang
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.rank == 1 ? const Color(0xFFFFD600) : Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.rank == 1 ? Icons.emoji_events : Icons.star,
                            color: widget.rank == 1 ? Colors.black : Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '#${widget.rank}',
                          style: TextStyle(
                              color: widget.rank == 1 ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                // Badge vidéo
                if (isVideo)
                  const Positioned(
                    bottom: 8,
                    right: 8,
                    child: Icon(Icons.play_circle_filled, color: Colors.white, size: 32),
                  ),
                // Badge audio
                if (isAudio)
                  const Positioned(
                    bottom: 8,
                    right: 8,
                    child: Icon(Icons.audiotrack, color: Colors.white, size: 24),
                  ),
              ],
            ),
            // Infos utilisateur
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null ? const Icon(Icons.person) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('$_subscriberCount abonnés', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  // Score totalInteractions
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blueGrey[800], borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        const Icon(Icons.bar_chart, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(_formatCount(totalInteractions),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Description courte
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                widget.post.description ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            // Statistiques : likes, commentaires, favoris
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildStatIcon(FontAwesome.heart_o, likes, Colors.red),
                  const SizedBox(width: 16),
                  _buildStatIcon(FontAwesome.comment_o, comments, Colors.blue),
                  const SizedBox(width: 16),
                  _buildStatIcon(Icons.bookmark_border, favorites, Colors.yellow),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Bouton encaisser (si gagnant et propriétaire)
            if (widget.isWinner && widget.onPayout != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ElevatedButton.icon(
                  onPressed: widget.onPayout,
                  icon: const Icon(Icons.monetization_on, size: 18),
                  label: const Text('Encaisser le prix'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStatIcon(IconData icon, int count, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFallbackContent(bool isVideo, bool isAudio, bool isText) {
    return Container(
      height: 180,
      width: double.infinity,
      color: Colors.grey[800],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isAudio)
              const Icon(Icons.audiotrack, size: 48, color: Colors.white70),
            if (isText)
              const Icon(Icons.text_fields, size: 48, color: Colors.white70),
            if (!isAudio && !isText)
              const Icon(Icons.image, size: 48, color: Colors.white70),
            const SizedBox(height: 8),
            Text(
              isAudio ? 'Audio' : (isText ? 'Texte' : 'Image manquante'),
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(height: 180, color: Colors.grey[800], child: const Center(child: CircularProgressIndicator()));
}