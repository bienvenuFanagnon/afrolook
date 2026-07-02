import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/widgets/boost_modal.dart';
import 'package:afrotok/pages/contenuPayant/widgets/content_comments_section.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ContentDetailPage extends StatefulWidget {
  final ContentPaie content;

  const ContentDetailPage({Key? key, required this.content}) : super(key: key);

  @override
  State<ContentDetailPage> createState() => _ContentDetailPageState();
}

class _ContentDetailPageState extends State<ContentDetailPage> {
  late ContentPaie _content;
  int _coverIndex = 0;
  bool _hasPurchased = false;
  bool _checkingPurchase = true;
  bool _buying = false;

  AppColors get _colors => AppColors.of(context);

  @override
  void initState() {
    super.initState();
    _content = widget.content;
    _checkPurchase();
    _incrementView();
  }

  Future<void> _checkPurchase() async {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    final uid = authProvider.userData?.id;
    if (uid == null || _content.id == null) {
      setState(() => _checkingPurchase = false);
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('ContentPurchases')
        .where('userId', isEqualTo: uid)
        .where('contentId', isEqualTo: _content.id)
        .limit(1)
        .get();
    if (mounted) {
      setState(() {
        _hasPurchased = snap.docs.isNotEmpty || _content.isFree;
        _checkingPurchase = false;
      });
    }
  }

  Future<void> _incrementView() async {
    if (_content.id == null) return;
    await FirebaseFirestore.instance
        .collection('ContentPaies')
        .doc(_content.id)
        .update({'views': FieldValue.increment(1)});
  }

  Future<void> _buy() async {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    final uid = authProvider.userData?.id;
    if (uid == null || _content.id == null) return;

    setState(() => _buying = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final purchaseRef =
          FirebaseFirestore.instance.collection('ContentPurchases').doc();
      batch.set(purchaseRef, {
        'userId': uid,
        'contentId': _content.id,
        'amountPaid': _content.price,
        'ownerEarnings': _content.price * 0.75,
        'platformEarnings': _content.price * 0.25,
        'purchaseDate': DateTime.now().millisecondsSinceEpoch,
      });
      batch.update(
          FirebaseFirestore.instance
              .collection('ContentPaies')
              .doc(_content.id!),
          {'sales': FieldValue.increment(1)});
      await batch.commit();
      if (mounted) setState(() => _hasPurchased = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  bool get _isOwner {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    return authProvider.userData?.id == _content.ownerId;
  }

  bool get _isAdmin {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    return authProvider.userData?.role == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: _colors.background,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.share_outlined,
                color: Colors.white, size: 18),
          ),
          onPressed: () {},
        ),
        if (_isOwner || _isAdmin)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.more_vert,
                  color: Colors.white, size: 18),
            ),
            onPressed: _showOwnerMenu,
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildCoverGallery(),
      ),
    );
  }

  Widget _buildCoverGallery() {
    final imgs = _content.coverImages;
    final hasCover = imgs.isNotEmpty;
    final coverCount = hasCover ? imgs.length : 1;

    return Stack(
      children: [
        if (hasCover)
          PageView.builder(
            itemCount: coverCount,
            onPageChanged: (i) => setState(() => _coverIndex = i),
            itemBuilder: (_, i) => _coverImage(imgs[i]),
          )
        else
          _coverPlaceholder(),

        // Gradient bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  _colors.background.withOpacity(0.9),
                ],
              ),
            ),
          ),
        ),

        // Type badge
        Positioned(
          top: 50,
          left: 16,
          child: _TypeBadge(type: _content.contentType),
        ),

        // Boost badge
        if (_content.isBoostActive)
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD400), Color(0xFFFF8C00)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.bolt, color: Colors.black, size: 12),
                  Text(' BOOSTÉ',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.black)),
                ],
              ),
            ),
          ),

        // Dots indicator
        if (coverCount > 1)
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                coverCount,
                (i) => Container(
                  width: i == _coverIndex ? 20 : 6,
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i == _coverIndex
                        ? const Color(0xFFFFD400)
                        : Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _coverImage(String url) {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    final cdnUrl =
        authProvider.convertToCdnUrl(url, authProvider.appDefaultData);
    return CachedNetworkImage(
      imageUrl: cdnUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      errorWidget: (_, __, ___) => _coverPlaceholder(),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: const Color(0xFF111111),
      child: Center(
        child: Text(
          _typeEmoji(_content.contentType),
          style: const TextStyle(fontSize: 60),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoSection(),
        _buildStatsRow(),
        const SizedBox(height: 8),
        _buildDescriptionSection(),
        if (!_hasPurchased && !_checkingPurchase && !_content.isFree)
          _buildPreviewSection(),
        if (_hasPurchased || _content.isFree) _buildDownloadSection(),
        if (_content.isSeries) _buildEpisodesList(),
        const SizedBox(height: 8),
        if (_content.id != null)
          ContentCommentsSection(contentId: _content.id!),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _content.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _colors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _colors.surface,
                child: Text(
                  _content.ownerId.isNotEmpty
                      ? _content.ownerId[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      fontSize: 12, color: _colors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Créateur',
                  style: TextStyle(
                      fontSize: 12, color: _colors.textSecondary),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFF25D366), width: 1.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '+ Suivre',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF25D366),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _StatChip(
              icon: Icons.visibility_outlined,
              value: _formatCount(_content.views)),
          const SizedBox(width: 12),
          _StatChip(
              icon: Icons.favorite_outline,
              value: _formatCount(_content.likes)),
          const SizedBox(width: 12),
          _StatChip(
              icon: Icons.download_outlined,
              value: _formatCount(_content.comments),
              label: 'achat'),
          if (_content.duration > 0) ...[
            const SizedBox(width: 12),
            _StatChip(
                icon: Icons.timer_outlined,
                value: _formatDuration(_content.duration)),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _content.description,
            style: TextStyle(
              fontSize: 13,
              color: _colors.textSecondary,
              height: 1.6,
            ),
          ),
          if (_content.hashtags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _content.hashtags
                  .map((h) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF25D366)
                                  .withOpacity(0.3)),
                        ),
                        child: Text(
                          '#$h',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF25D366)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'APERÇU GRATUIT',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: _colors.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: 5,
            itemBuilder: (_, i) {
              final authProvider =
                  Provider.of<UserAuthProvider>(context, listen: false);
              final imgs = _content.coverImages;
              final isLocked = i >= (imgs.isEmpty ? 1 : imgs.length);
              final url = imgs.isNotEmpty && i < imgs.length
                  ? authProvider.convertToCdnUrl(
                      imgs[i], authProvider.appDefaultData)
                  : '';
              return Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _colors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url.isNotEmpty && !isLocked)
                      CachedNetworkImage(
                          imageUrl: url, fit: BoxFit.cover)
                    else
                      Center(
                          child: Text(_typeEmoji(_content.contentType),
                              style:
                                  const TextStyle(fontSize: 28))),
                    if (isLocked)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Icon(Icons.lock_outline,
                              color: Colors.white, size: 22),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            'Achetez pour accéder à tout le contenu',
            style: TextStyle(
                fontSize: 10, color: _colors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadSection() {
    if (!_content.hasFile && _content.tutorialVideoUrl == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF25D366).withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download_done_outlined,
                    color: Color(0xFF25D366), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Vos fichiers — téléchargement sécurisé',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF25D366),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_content.hasFile)
              _DownloadTile(
                icon: Icons.folder_zip_outlined,
                name: 'Fichier principal',
                size: _content.fileSize ?? '',
                color: const Color(0xFF25D366),
                onTap: () => _downloadFile(_content.fileUrl!),
              ),
            if (_content.tutorialVideoUrl != null) ...[
              const SizedBox(height: 8),
              _DownloadTile(
                icon: Icons.play_circle_outline,
                name: 'Tutoriel vidéo',
                size: 'MP4',
                color: const Color(0xFF4a90e2),
                onTap: () =>
                    _downloadFile(_content.tutorialVideoUrl!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ÉPISODES',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: _colors.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Episodes')
              .where('seriesId', isEqualTo: _content.id)
              .orderBy('episodeNumber')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator()));
            }
            final eps = snap.data!.docs
                .map((d) => Episode.fromJson(
                    {...d.data() as Map<String, dynamic>, 'id': d.id}))
                .toList();
            if (eps.isEmpty) return const SizedBox.shrink();
            return Column(
              children: eps
                  .map((ep) => _EpisodeRow(
                      episode: ep,
                      hasPurchased: _hasPurchased,
                      colors: _colors))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    if (_checkingPurchase) {
      return const SizedBox(height: 80);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: BoxDecoration(
        color: _colors.background,
        border: Border(top: BorderSide(color: _colors.divider)),
      ),
      child: Row(
        children: [
          if (!_hasPurchased && !_content.isFree) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_content.price.toInt()} F',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD400),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
          ],
          if (_hasPurchased || _content.isFree)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF25D366).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.check_circle_outline,
                        color: Color(0xFF25D366), size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Contenu débloqué',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF25D366)),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            if (_isOwner || _isAdmin)
              OutlinedButton.icon(
                onPressed: () => BoostModal.show(context, _content,
                    isAdmin: _isAdmin),
                icon: const Icon(Icons.bolt,
                    size: 16, color: Color(0xFFFFD400)),
                label: const Text('Booster',
                    style: TextStyle(color: Color(0xFFFFD400))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: Color(0xFFFFD400), width: 1.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () => BoostModal.show(context, _content),
                icon: const Icon(Icons.bolt,
                    size: 16, color: Color(0xFFFFD400)),
                label: const Text('Booster',
                    style: TextStyle(color: Color(0xFFFFD400))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: Color(0xFFFFD400), width: 1.5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _buying ? null : _buy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _buying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white))
                    : const Text(
                        'Acheter maintenant',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showOwnerMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bolt, color: Color(0xFFFFD400)),
              title: Text(_isAdmin ? 'Booster (gratuit)' : 'Booster'),
              onTap: () {
                Navigator.pop(context);
                BoostModal.show(context, _content, isAdmin: _isAdmin);
              },
            ),
            if (_isOwner)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier le contenu'),
                onTap: () => Navigator.pop(context),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Supprimer',
                  style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(String url) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Téléchargement en cours...')),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}';
    return '${m}min';
  }

  String _typeEmoji(ContentType t) {
    switch (t) {
      case ContentType.VIDEO:
        return '🎬';
      case ContentType.EBOOK:
        return '📘';
      case ContentType.FORMATION:
        return '🎓';
      case ContentType.TEMPLATE:
        return '🎨';
      case ContentType.PACK_ZIP:
        return '📦';
      case ContentType.AUDIO:
        return '🎵';
      case ContentType.PRESET:
        return '🎛️';
      case ContentType.BUNDLE:
        return '🗂️';
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String? label;

  const _StatChip({required this.icon, required this.value, this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.textSecondary),
        const SizedBox(width: 3),
        Text(
          label != null ? '$value $label' : value,
          style: TextStyle(fontSize: 11, color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ContentType type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _info(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  (String, Color) _info(ContentType t) {
    switch (t) {
      case ContentType.VIDEO:
        return ('VIDÉO', const Color(0xFF4a90e2));
      case ContentType.EBOOK:
        return ('EBOOK', const Color(0xFF9b59b6));
      case ContentType.FORMATION:
        return ('FORMATION', const Color(0xFF8e44ad));
      case ContentType.TEMPLATE:
        return ('TEMPLATE', const Color(0xFFFFD400));
      case ContentType.PACK_ZIP:
        return ('PACK ZIP', const Color(0xFF25D366));
      case ContentType.AUDIO:
        return ('AUDIO', const Color(0xFFe67e22));
      case ContentType.PRESET:
        return ('PRESET', const Color(0xFF1abc9c));
      case ContentType.BUNDLE:
        return ('BUNDLE', const Color(0xFFe74c3c));
    }
  }
}

class _DownloadTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final String size;
  final Color color;
  final VoidCallback onTap;

  const _DownloadTile({
    required this.icon,
    required this.name,
    required this.size,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary)),
                  if (size.isNotEmpty)
                    Text(size,
                        style: TextStyle(
                            fontSize: 10,
                            color: colors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Text(
                icon == Icons.play_circle_outline ? '▶' : '⬇',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatelessWidget {
  final Episode episode;
  final bool hasPurchased;
  final AppColors colors;

  const _EpisodeRow({
    required this.episode,
    required this.hasPurchased,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = !hasPurchased && !episode.isFree;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isLocked
                  ? colors.surface
                  : const Color(0xFF25D366).withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: isLocked
                    ? colors.divider
                    : const Color(0xFF25D366).withOpacity(0.4),
              ),
            ),
            child: Center(
              child: Text(
                'E${episode.episodeNumber}',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isLocked
                        ? colors.textSecondary
                        : const Color(0xFF25D366)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 52,
            height: 38,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text('🎬', style: const TextStyle(fontSize: 18)),
                if (isLocked)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.lock_outline,
                        color: Colors.white, size: 14),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  episode.isFree
                      ? 'Gratuit'
                      : '${episode.price.toInt()} F',
                  style: TextStyle(
                      fontSize: 10,
                      color: episode.isFree
                          ? const Color(0xFF25D366)
                          : const Color(0xFFFFD400)),
                ),
              ],
            ),
          ),
          if (!isLocked)
            const Icon(Icons.play_circle_outline,
                color: Color(0xFF25D366), size: 26)
          else
            const Icon(Icons.lock_outline, color: Colors.grey, size: 20),
        ],
      ),
    );
  }
}
