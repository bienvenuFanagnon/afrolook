import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/chatmodels/message.dart';
import '../../models/enums.dart';
import '../../theme/app_colors.dart';

/// Galerie des médias échangés dans une conversation.
/// Accessible depuis le menu ⋮ du chat.
class ChatMediaGalleryPage extends StatefulWidget {
  final String chatId;
  final String chatTitle;

  const ChatMediaGalleryPage({
    Key? key,
    required this.chatId,
    required this.chatTitle,
  }) : super(key: key);

  @override
  State<ChatMediaGalleryPage> createState() => _ChatMediaGalleryPageState();
}

class _ChatMediaGalleryPageState extends State<ChatMediaGalleryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AppColors _colors;

  // Photos
  List<Message> _images = [];
  bool _loadingImages = true;
  DocumentSnapshot? _lastImageDoc;
  bool _hasMoreImages = true;
  static const int _pageSize = 20;

  // Audios
  List<Message> _audios = [];
  bool _loadingAudios = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadImages();
    _loadAudios();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadImages({bool loadMore = false}) async {
    if (!_hasMoreImages && loadMore) return;

    setState(() => _loadingImages = !loadMore);

    try {
      Query query = FirebaseFirestore.instance
          .collection('Messages')
          .where('chat_id', isEqualTo: widget.chatId)
          .where('messageType', isEqualTo: MessageType.image.name)
          .where('is_valide', isEqualTo: true)
          .orderBy('create_at_time_spam', descending: true)
          .limit(_pageSize);

      if (loadMore && _lastImageDoc != null) {
        query = query.startAfterDocument(_lastImageDoc!);
      }

      final snap = await query.get();
      final newItems = snap.docs
          .map((d) => Message.fromJson(d.data() as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          if (loadMore) {
            _images.addAll(newItems);
          } else {
            _images = newItems;
          }
          _loadingImages = false;
          _hasMoreImages = newItems.length == _pageSize;
          if (snap.docs.isNotEmpty) _lastImageDoc = snap.docs.last;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  Future<void> _loadAudios() async {
    setState(() => _loadingAudios = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Messages')
          .where('chat_id', isEqualTo: widget.chatId)
          .where('messageType', isEqualTo: MessageType.voice.name)
          .where('is_valide', isEqualTo: true)
          .orderBy('create_at_time_spam', descending: true)
          .limit(50)
          .get();

      if (mounted) {
        setState(() {
          _audios = snap.docs
              .map((d) => Message.fromJson(d.data() as Map<String, dynamic>))
              .toList();
          _loadingAudios = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingAudios = false);
    }
  }

  void _openImageFullScreen(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImage(url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _colors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Médias partagés',
          style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _colors.primary,
          labelColor: _colors.primary,
          unselectedLabelColor: _colors.textSecondary,
          tabs: const [
            Tab(text: 'Photos'),
            Tab(text: 'Audios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPhotosTab(),
          _buildAudiosTab(),
        ],
      ),
    );
  }

  Widget _buildPhotosTab() {
    if (_loadingImages) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_images.isEmpty) {
      return _buildEmpty('Aucune photo partagée', Icons.photo_library_outlined);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notif) {
        if (notif.metrics.pixels >= notif.metrics.maxScrollExtent - 200) {
          _loadImages(loadMore: true);
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
        ),
        itemCount: _images.length + (_hasMoreImages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _images.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final msg = _images[index];
          // Support multi-images (URLs séparées par |)
          final urls = msg.imageText != null && msg.imageText!.contains('|')
              ? [msg.message, ...msg.imageText!.split('|').where((u) => u.isNotEmpty)]
              : [msg.message];

          return GestureDetector(
            onTap: () => _openImageFullScreen(urls.first),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: urls.first,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: _colors.surfaceVariant),
                  errorWidget: (_, __, ___) => Container(
                    color: _colors.surfaceVariant,
                    child: Icon(Icons.broken_image, color: _colors.textSecondary),
                  ),
                ),
                if (urls.length > 1)
                  Positioned(
                    top: 4, right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+${urls.length - 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudiosTab() {
    if (_loadingAudios) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_audios.isEmpty) {
      return _buildEmpty('Aucun message vocal partagé', Icons.mic_none_rounded);
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _audios.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: _colors.border.withOpacity(0.3)),
      itemBuilder: (context, index) {
        final msg = _audios[index];
        final date = DateTime.fromMillisecondsSinceEpoch(msg.create_at_time_spam);
        final timeStr = '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

        return ListTile(
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _colors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mic_rounded, color: _colors.primary, size: 22),
          ),
          title: Text(
            'Message vocal',
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            timeStr,
            style: TextStyle(color: _colors.textSecondary, fontSize: 12),
          ),
          trailing: Icon(Icons.play_circle_outline_rounded, color: _colors.primary, size: 28),
        );
      },
    );
  }

  Widget _buildEmpty(String label, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _colors.textSecondary, size: 56),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: _colors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

// ── Visionneuse plein écran ─────────────────────────────────────────────────
class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
