import 'package:flutter/material.dart';
import '../../../models/model_data.dart';
import '../../../pages/UserServices/ServiceWidget.dart';
import '../../../pages/canaux/listCanal.dart';
import '../../../theme/app_colors.dart';

/// Section horizontale de canaux Afrolook.
class FeedCanauxSection extends StatelessWidget {
  final List<Canal> canaux;
  final bool isLoading;
  final String title;
  final String seeMoreLabel;

  const FeedCanauxSection({
    Key? key,
    required this.canaux,
    this.isLoading = false,
    required this.title,
    required this.seeMoreLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading || canaux.isEmpty) return const SizedBox.shrink();

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
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CanalListPage(isUserCanals: false)),
                  ),
                  child: Row(
                    children: [
                      Text(seeMoreLabel,
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
          ),
          SizedBox(
            height: size.height * 0.22,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: canaux.length,
              itemBuilder: (_, i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: size.width * 0.28,
                child: channelWidget(
                  canaux[i],
                  size.height * 0.25,
                  size.width * 0.3,
                  context,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingSection extends StatelessWidget {
  final String title;
  const _LoadingSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFF25D366)),
          ),
        ],
      ),
    );
  }
}
