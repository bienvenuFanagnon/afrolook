import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/model_data.dart';
import '../../../pages/afroshop/marketPlace/acceuil/home_afroshop.dart';
import '../../../theme/app_colors.dart';

/// Widget AfroShop dans le fil d'actualité — 3 produits aléatoires + CTA boutique.
/// [isFirstPosition] change la palette (ambre) pour la variante "à la une" du lundi/jeudi.
class ShopPromoFeedWidget extends StatelessWidget {
  final List<ArticleData> articles;
  final bool isFirstPosition;

  const ShopPromoFeedWidget({
    Key? key,
    required this.articles,
    this.isFirstPosition = false,
  }) : super(key: key);

  List<ArticleData> get _picks {
    if (articles.isEmpty) return [];
    final list = List<ArticleData>.from(articles)..shuffle(Random());
    return list.take(3).toList();
  }

  void _openShop(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomeAfroshopPage(title: '')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final picks = _picks;
    if (picks.isEmpty) return const SizedBox.shrink();

    final accent = isFirstPosition ? const Color(0xFFF0A500) : colors.primary;
    final bg = isFirstPosition
        ? (colors.isDark ? const Color(0xFF1A1000) : const Color(0xFFFFF8E7))
        : colors.surface;
    final title = isFirstPosition ? '🔥 Produits en tendance' : '🛍 AfroShop Boutique';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: BorderSide(color: accent, width: 2),
          bottom: BorderSide(color: accent, width: 2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                GestureDetector(
                  onTap: () => _openShop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Voir tout →',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 3 produits
            Row(
              children: picks.map((article) {
                final imgUrl = article.thumbnailUrl ??
                    (article.images?.isNotEmpty == true ? article.images!.first : null);
                final price = article.prix != null
                    ? '${article.prix!.toStringAsFixed(0)} F'
                    : '';
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () => _openShop(context),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: imgUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: imgUrl,
                                    height: 80,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      height: 80,
                                      color: Colors.grey[800],
                                    ),
                                  )
                                : Container(height: 80, color: Colors.grey[800]),
                          ),
                          if (price.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              price,
                              style: TextStyle(
                                color: isFirstPosition ? colors.primary : accent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            // CTA
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openShop(context),
                icon: const Icon(Icons.storefront_rounded, size: 16),
                label: const Text('Visiter la boutique AfroShop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: isFirstPosition ? Colors.black : Colors.white,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Variante plein écran pour le scroll vidéo AfroShop.
/// S'affiche comme un item PageView à la place d'une vidéo (toutes les 7).
class ShopPromoVideoItem extends StatelessWidget {
  final List<ArticleData> articles;

  const ShopPromoVideoItem({Key? key, required this.articles}) : super(key: key);

  List<ArticleData> get _picks {
    if (articles.isEmpty) return [];
    final list = List<ArticleData>.from(articles)..shuffle(Random());
    return list.take(3).toList();
  }

  void _openShop(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomeAfroshopPage(title: '')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final picks = _picks;
    final size = MediaQuery.of(context).size;

    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // En-tête gradient
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D2818), Color(0xFF0D1510)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2ECC71), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🛍 AfroShop',
                  style: TextStyle(
                    color: Color(0xFF2ECC71),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0A500).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BOUTIQUE',
                    style: TextStyle(
                      color: Color(0xFFF0A500),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // 3 produits
          if (picks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: picks.map((article) {
                  final imgUrl = article.thumbnailUrl ??
                      (article.images?.isNotEmpty == true ? article.images!.first : null);
                  final price = article.prix != null
                      ? '${article.prix!.toStringAsFixed(0)} F'
                      : '';
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => _openShop(context),
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: imgUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: imgUrl,
                                      height: size.width * 0.28,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        height: size.width * 0.28,
                                        color: const Color(0xFF1A1A1A),
                                      ),
                                    )
                                  : Container(
                                      height: size.width * 0.28,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                            ),
                            if (price.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                price,
                                style: const TextStyle(
                                  color: Color(0xFFF0A500),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 24),
          // CTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openShop(context),
                icon: const Icon(Icons.storefront_rounded),
                label: const Text('Voir la boutique AfroShop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Glissez vers le haut pour continuer',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
