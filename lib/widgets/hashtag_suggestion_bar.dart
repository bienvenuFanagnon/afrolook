import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HashtagSuggestionBar extends StatelessWidget {
  final String? selectedPostType;
  final TextEditingController descriptionController;
  final VoidCallback? onHashtagAdded;

  const HashtagSuggestionBar({
    Key? key,
    required this.selectedPostType,
    required this.descriptionController,
    this.onHashtagAdded,
  }) : super(key: key);

  static const Map<String, List<String>> _hashtagsByType = {
    'LOOKS': [
      '#mode', '#fashion', '#look', '#outfit', '#wax', '#pagne', '#style',
      '#afrofashion', '#ootd', '#tendance', '#beauté', '#slay', '#tenue',
      '#afrostyle', '#ankara',
    ],
    'SPORT': [
      '#sport', '#football', '#basket', '#CAN2025', '#match', '#victoire',
      '#champion', '#fitness', '#afrosport', '#goal', '#athletisme', '#liga',
      '#ligue1', '#training', '#motivation',
    ],
    'ACTUALITES': [
      '#actu', '#news', '#info', '#politique', '#afrique', '#togo', '#senegal',
      '#côtedivoire', '#breaking', '#débat', '#cameroun', '#ghana',
      '#afrique2025', '#international', '#société',
    ],
    'EVENEMENT': [
      '#evenement', '#concert', '#festival', '#soirée', '#lancement', '#invitation',
      '#VIP', '#afterwork', '#rencontre', '#fête', '#spectacle', '#show',
      '#agenda', '#sortie', '#gratuit',
    ],
    'OFFRES': [
      '#offre', '#promo', '#vente', '#deal', '#shopping', '#reduction', '#business',
      '#opportunite', '#commande', '#livraison', '#achat', '#boutique',
      '#soldes', '#nouveauté', '#startup',
    ],
    'GAMER': [
      '#gaming', '#game', '#gamer', '#PS5', '#mobile', '#esport', '#jeux',
      '#streamer', '#freefire', '#playstation', '#xbox', '#PUBG',
      '#mobilegaming', '#codm', '#afrogaming',
    ],
  };

  static const List<String> _universalHashtags = [
    '#afrolook', '#afrique', '#viral', '#fyp', '#trending',
  ];

  List<String> _buildSuggestions() {
    final List<String> list = [];
    if (selectedPostType != null && _hashtagsByType.containsKey(selectedPostType)) {
      list.addAll(_hashtagsByType[selectedPostType]!);
    }
    list.addAll(_universalHashtags);
    return list;
  }

  bool _isAlreadyUsed(String tag) {
    return descriptionController.text.toLowerCase().contains(tag.toLowerCase());
  }

  void _addHashtag(String tag) {
    final current = descriptionController.text;
    final toAdd = (current.isEmpty || current.endsWith(' ')) ? tag : ' $tag';
    descriptionController.text = '$current$toAdd ';
    descriptionController.selection = TextSelection.fromPosition(
      TextPosition(offset: descriptionController.text.length),
    );
    onHashtagAdded?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (selectedPostType == null) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final suggestions = _buildSuggestions();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tag_rounded, size: 14, color: c.primary),
              const SizedBox(width: 4),
              Text(
                'Hashtags suggérés — tape pour ajouter',
                style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final tag = suggestions[i];
                final used = _isAlreadyUsed(tag);
                return GestureDetector(
                  onTap: used ? null : () => _addHashtag(tag),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: used
                          ? c.surfaceVariant.withOpacity(0.4)
                          : c.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: used ? c.border : c.primary.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: used ? c.textSecondary : c.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        decoration: used ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
