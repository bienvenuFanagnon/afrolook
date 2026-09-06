// lib/pages/challenge/challenge_post_card.dart
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
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
  String _optimizeUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final appDefaultData = authProvider.appDefaultData;

    return authProvider.convertToCdnUrl(url, appDefaultData);
  }

  @override
  void initState() {
    super.initState();
    final swPost = Stopwatch()..start();
    final postId   = widget.post.id ?? '?';
    final isCanalPost = widget.post.canal_id != null && widget.post.canal_id!.isNotEmpty;
    printVm('⏱️ [CHALLENGE-CARD] id=$postId canal=$isCanalPost — initState start');

    _initFromSnapshot();
    final snapMs = swPost.elapsedMilliseconds;
    final hadSnapshot = isCanalPost ? widget.post.canalSnapshot != null : widget.post.creatorSnapshot != null;
    printVm('⏱️ [CHALLENGE-CARD] id=$postId — snapshot=${hadSnapshot ? "✅ ${snapMs}ms" : "❌ pas de snapshot"}');

    _loadCreatorData().then((_) {
      printVm('⏱️ [CHALLENGE-CARD] id=$postId — profil complet — total=${swPost.elapsedMilliseconds}ms');
    });
  }

  void _initFromSnapshot() {
    if (widget.post.user != null) { _user = widget.post.user; return; }
    if (widget.post.canal != null) { _canal = widget.post.canal; return; }
    final isCanalPost = widget.post.canal_id != null && widget.post.canal_id!.isNotEmpty;
    if (isCanalPost) {
      final snap = widget.post.canalSnapshot;
      if (snap != null) {
        _canal = Canal()
          ..titre = snap['titre'] as String?
          ..urlImage = snap['urlImage'] as String?
          ..suivi = snap['suivi'] as int? ?? 0;
      }
    } else {
      final snap = widget.post.creatorSnapshot;
      if (snap != null) {
        _user = UserData()
          ..pseudo = snap['pseudo'] as String?
          ..imageUrl = snap['imageUrl'] as String?
          ..abonnes = snap['abonnes'] as int? ?? 0;
      }
    }
  }

  Future<void> _loadCreatorData() async {
    // Réutilise le cache post si déjà chargé (snapshot ou scroll retour)
    if (widget.post.user != null) { _user = widget.post.user; if (mounted) setState(() {}); return; }
    if (widget.post.canal != null) { _canal = widget.post.canal; if (mounted) setState(() {}); return; }

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
      printVm('Erreur chargement créateur: $e');
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
    if (_canal != null) return _canal!.suivi ?? _canal!.usersSuiviId?.length ?? 0;
    if (_user != null) return _user!.abonnes ?? _user!.userAbonnesIds?.length ?? 0;
    return 0;
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
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
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator(color: colors.accent)),
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
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: widget.isWinner ? Border.all(color: colors.accent, width: 2) : Border.all(color: colors.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniature média + badge rang
            Stack(
              children: [
                if (isVideo && (thumbnail != null && thumbnail.isNotEmpty))
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    child: Image.network(thumbnail, height: 180, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackContent(isVideo, isAudio, isText, colors)),
                  )
                else if (hasImage)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: _optimizeUrl(widget.post.images!.first),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder(colors),
                      errorWidget: (_, __, ___) => _buildFallbackContent(isVideo, isAudio, isText, colors),
                    ),
                  )
                else
                  _buildFallbackContent(isVideo, isAudio, isText, colors),
                // Badge rang
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.rank == 1 ? colors.accent : Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.rank == 1 ? Icons.emoji_events : Icons.star,
                            color: widget.rank == 1 ? colors.onAccent : Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '#${widget.rank}',
                          style: TextStyle(
                              color: widget.rank == 1 ? colors.onAccent : Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isVideo)
                  const Positioned(
                    bottom: 8, right: 8,
                    child: Icon(Icons.play_circle_filled, color: Colors.white, size: 32),
                  ),
                if (isAudio)
                  const Positioned(
                    bottom: 8, right: 8,
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
                    backgroundColor: colors.surfaceVariant,
                    backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null ? Icon(Icons.person, color: colors.textSecondary) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_displayName, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                        Text('$_subscriberCount abonnés', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  // Score totalInteractions
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        Icon(Icons.bar_chart, color: colors.accent, size: 16),
                        const SizedBox(width: 4),
                        Text(_formatCount(totalInteractions),
                            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
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
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            // Statistiques
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildStatIcon(FontAwesome.heart_o, likes, colors.danger, colors),
                  const SizedBox(width: 16),
                  _buildStatIcon(FontAwesome.comment_o, comments, colors.info, colors),
                  const SizedBox(width: 16),
                  _buildStatIcon(Icons.bookmark_border, favorites, colors.accent, colors),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Bouton encaisser
            if (widget.isWinner && widget.onPayout != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ElevatedButton.icon(
                  onPressed: widget.onPayout,
                  icon: const Icon(Icons.monetization_on, size: 18),
                  label: const Text('Encaisser le prix'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
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

  Widget _buildStatIcon(IconData icon, int count, Color color, AppColors colors) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(_formatCount(count), style: TextStyle(color: colors.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _buildFallbackContent(bool isVideo, bool isAudio, bool isText, AppColors colors) {
    return Container(
      height: 180,
      width: double.infinity,
      color: colors.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isAudio) Icon(Icons.audiotrack, size: 48, color: colors.textSecondary),
            if (isText) Icon(Icons.text_fields, size: 48, color: colors.textSecondary),
            if (!isAudio && !isText) Icon(Icons.image, size: 48, color: colors.textSecondary),
            const SizedBox(height: 8),
            Text(
              isAudio ? 'Audio' : (isText ? 'Texte' : 'Image manquante'),
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(AppColors colors) => Container(
        height: 180,
        color: colors.surfaceVariant,
        child: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
}