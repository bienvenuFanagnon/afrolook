import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/content_detail_page.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyPurchasesPage extends StatefulWidget {
  const MyPurchasesPage({Key? key}) : super(key: key);

  @override
  State<MyPurchasesPage> createState() => _MyPurchasesPageState();
}

class _MyPurchasesPageState extends State<MyPurchasesPage> {
  AppColors get _colors => AppColors.of(context);

  Future<List<ContentPaie>> _loadPurchases(String uid) async {
    // 1. Charger tous les achats de l'utilisateur
    final purchaseSnap = await FirebaseFirestore.instance
        .collection('ContentPaie_purchases')
        .where('userId', isEqualTo: uid)
        .orderBy('purchaseDate', descending: true)
        .get();

    if (purchaseSnap.docs.isEmpty) return [];

    // 2. Récupérer les ids de contenu uniques
    final contentIds = purchaseSnap.docs
        .map((d) => d.data()['contentId'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    if (contentIds.isEmpty) return [];

    // 3. Charger les docs contenu en parallèle (par lots de 10 — limite Firestore whereIn)
    final contents = <ContentPaie>[];
    for (var i = 0; i < contentIds.length; i += 10) {
      final chunk = contentIds.sublist(i, (i + 10).clamp(0, contentIds.length));
      final snap = await FirebaseFirestore.instance
          .collection('ContentPaies')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        contents.add(ContentPaie.fromJson({...doc.data(), 'id': doc.id}));
      }
    }

    // Respecter l'ordre chronologique des achats
    contents.sort((a, b) {
      final ia = contentIds.indexOf(a.id ?? '');
      final ib = contentIds.indexOf(b.id ?? '');
      return ia.compareTo(ib);
    });

    return contents;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final uid = authProvider.loginUserData.id ?? '';

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.surface,
        elevation: 0,
        title: Text(
          'Mes achats',
          style: TextStyle(
              color: _colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800),
        ),
        iconTheme: IconThemeData(color: _colors.textPrimary),
      ),
      body: FutureBuilder<List<ContentPaie>>(
        future: _loadPurchases(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: _colors.primary));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Erreur de chargement',
                  style: TextStyle(color: _colors.textSecondary)),
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) return _buildEmpty();
          return _buildList(items, authProvider);
        },
      ),
    );
  }

  Widget _buildList(List<ContentPaie> items, UserAuthProvider authProvider) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _PurchasedContentTile(
        content: items[i],
        authProvider: authProvider,
        colors: _colors,
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 64, color: _colors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'Aucun achat pour l\'instant',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Les contenus que vous achetez\napparaîtront ici.',
            style: TextStyle(fontSize: 13, color: _colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Tile d'un contenu acheté ──────────────────────────────────────────────────

class _PurchasedContentTile extends StatelessWidget {
  final ContentPaie content;
  final UserAuthProvider authProvider;
  final AppColors colors;

  const _PurchasedContentTile({
    required this.content,
    required this.authProvider,
    required this.colors,
  });

  String _typeLabel(ContentType? t) {
    switch (t) {
      case ContentType.VIDEO: return 'Vidéo';
      case ContentType.EBOOK: return 'Ebook';
      case ContentType.FORMATION: return 'Formation';
      case ContentType.TEMPLATE: return 'Template';
      case ContentType.PACK_ZIP: return 'Pack';
      case ContentType.AUDIO: return 'Audio';
      case ContentType.PRESET: return 'Preset';
      case ContentType.BUNDLE: return 'Bundle';
      default: return 'Contenu';
    }
  }

  String _typeEmoji(ContentType? t) {
    switch (t) {
      case ContentType.VIDEO: return '🎬';
      case ContentType.EBOOK: return '📘';
      case ContentType.FORMATION: return '🎓';
      case ContentType.TEMPLATE: return '🎨';
      case ContentType.PACK_ZIP: return '📦';
      case ContentType.AUDIO: return '🎵';
      case ContentType.PRESET: return '🎛️';
      case ContentType.BUNDLE: return '🗂️';
      default: return '📄';
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = content.coverImages.isNotEmpty
        ? content.coverImages.first
        : content.thumbnailUrl;
    final cdnUrl = authProvider.convertToCdnUrl(coverUrl, authProvider.appDefaultData);
    final hasValidCover = coverUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ContentDetailPage(content: content)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            // Vignette
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              child: SizedBox(
                width: 90,
                height: 90,
                child: hasValidCover
                    ? CachedNetworkImage(
                        imageUrl: cdnUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),
            // Infos
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge type
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_typeEmoji(content.contentType)} ${_typeLabel(content.contentType)}',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: colors.primary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 13, color: const Color(0xFF25D366)),
                        const SizedBox(width: 4),
                        Text(
                          'Acheté',
                          style: TextStyle(
                              fontSize: 11,
                              color: const Color(0xFF25D366),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Flèche
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: colors.surfaceVariant,
        child: Center(
          child: Text(_typeEmoji(content.contentType),
              style: const TextStyle(fontSize: 28)),
        ),
      );
}
