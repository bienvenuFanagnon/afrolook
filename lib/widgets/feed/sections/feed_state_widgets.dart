import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// ── Spinner de section (titre + indicateur) ─────────────────────────────────

class FeedSectionLoader extends StatelessWidget {
  final String title;
  const FeedSectionLoader({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF25D366)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer pleine page (chroniques + posts) ─────────────────────────────────

class FeedLoadingShimmer extends StatelessWidget {
  const FeedLoadingShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (_, __) => Container(
                width: width * 0.2,
                margin: const EdgeInsets.all(4),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, __) => Container(
              margin: const EdgeInsets.all(8),
              child: Shimmer.fromColors(
                baseColor: Colors.grey[800]!,
                highlightColor: Colors.grey[700]!,
                child: Container(
                  height: 350,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            childCount: 2,
          ),
        ),
      ],
    );
  }
}

// ── État erreur ──────────────────────────────────────────────────────────────

class FeedErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  const FeedErrorWidget({Key? key, required this.onRetry}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          const Text('Erreur de chargement',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Réessayer', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── État vide ────────────────────────────────────────────────────────────────

class FeedEmptyWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const FeedEmptyWidget(
      {Key? key, required this.message, required this.onRetry})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.feed, color: Colors.grey, size: 40),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Actualiser', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
