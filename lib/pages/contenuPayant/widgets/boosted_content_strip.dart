import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/content_detail_page.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BoostedContentStripWidget extends StatelessWidget {
  const BoostedContentStripWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ContentPaies')
          .where('isBoosted', isEqualTo: true)
          .where('boostEndDate',
              isGreaterThan: DateTime.now().millisecondsSinceEpoch)
          .orderBy('boostEndDate', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final items = snapshot.data!.docs
            .map((d) => ContentPaie.fromJson(
                {...d.data() as Map<String, dynamic>, 'id': d.id}))
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.bolt, color: const Color(0xFFFFD400), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'BUSINESS BOOSTÉS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFD400),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFFD400).withOpacity(0.4),
                            Colors.transparent
                          ],
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/boutique'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Voir tout',
                        style: TextStyle(
                            fontSize: 10,
                            color: colors.textSecondary)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 148,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                itemBuilder: (context, i) =>
                    _BoostedCard(content: items[i], colors: colors),
              ),
            ),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}

class _BoostedCard extends StatelessWidget {
  final ContentPaie content;
  final AppColors colors;

  const _BoostedCard({required this.content, required this.colors});

  @override
  Widget build(BuildContext context) {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    final coverUrl = content.coverImages.isNotEmpty
        ? content.coverImages.first
        : content.thumbnailUrl;
    final cdnCover = authProvider.convertToCdnUrl(
        coverUrl, authProvider.appDefaultData);

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ContentDetailPage(content: content))),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFFFD400).withOpacity(0.3), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 80,
                  width: double.infinity,
                  child: cdnCover.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: cdnCover,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _coverPlaceholder(),
                        )
                      : _coverPlaceholder(),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD400),
                          const Color(0xFFFF8C00)
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt,
                            color: Colors.black, size: 10),
                        Text(
                          ' SPONSORISÉ',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _typeLabel(content.contentType),
                    style: TextStyle(
                        fontSize: 9, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content.isFree
                        ? 'GRATUIT'
                        : '${content.price.toInt()} F',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: content.isFree
                          ? const Color(0xFF25D366)
                          : const Color(0xFFFFD400),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      height: 80,
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Text(_typeEmoji(content.contentType),
            style: const TextStyle(fontSize: 28)),
      ),
    );
  }

  String _typeLabel(ContentType t) {
    switch (t) {
      case ContentType.VIDEO:
        return 'Vidéo';
      case ContentType.EBOOK:
        return 'Ebook';
      case ContentType.FORMATION:
        return 'Formation';
      case ContentType.TEMPLATE:
        return 'Template';
      case ContentType.PACK_ZIP:
        return 'Pack ZIP';
      case ContentType.AUDIO:
        return 'Audio';
      case ContentType.PRESET:
        return 'Preset';
      case ContentType.BUNDLE:
        return 'Bundle';
    }
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
