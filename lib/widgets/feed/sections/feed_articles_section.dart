import 'package:flutter/material.dart';
import '../../../models/model_data.dart';
import '../../../pages/afroshop/marketPlace/component.dart';
import '../../../pages/afroshop/marketPlace/acceuil/home_afroshop.dart';
import '../../../theme/app_colors.dart';

/// Section horizontale d'articles/produits boostés.
class FeedArticlesSection extends StatelessWidget {
  final List<ArticleData> articles;
  final bool isLoading;
  final String title;
  final String seeMoreLabel;

  const FeedArticlesSection({
    Key? key,
    required this.articles,
    this.isLoading = false,
    required this.title,
    required this.seeMoreLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading || articles.isEmpty) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;
    final colors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _SectionHeader(
            title: title,
            actionLabel: seeMoreLabel,
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomeAfroshopPage(title: '')),
            ),
          ),
          SizedBox(
            height: size.height * 0.22,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: articles.length,
              itemBuilder: (_, i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: size.width * 0.55,
                child: ProductWidget(
                  article: articles[i],
                  width: size.width * 0.55,
                  height: size.height * 0.22,
                  isOtherPage: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header réutilisable interne ───────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.textPrimary),
          ),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF25D366)),
            )
          else if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Row(
                children: [
                  Text(actionLabel!,
                      style: const TextStyle(
                          color: Color(0xFF25D366),
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward,
                      color: Color(0xFF25D366), size: 14),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
