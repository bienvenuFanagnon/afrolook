import 'package:flutter/material.dart';

/// Barre de filtres pays réutilisable (Tous / Mon pays / Mix / Autre).
/// [trailingChildren] : widgets optionnels ajoutés à la fin de la barre (séparés par un divider).
class FeedFilterBar extends StatelessWidget {
  final String currentFilter;
  final String? selectedCountryCode;
  final void Function({required String filterType, String? countryCode}) onApplyFilter;
  final VoidCallback? onShowCountryModal;
  final List<Widget> trailingChildren;

  const FeedFilterBar({
    Key? key,
    required this.currentFilter,
    required this.selectedCountryCode,
    required this.onApplyFilter,
    this.onShowCountryModal,
    this.trailingChildren = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          FeedFilterChip(
            label: '🌍 Tous',
            isSelected: currentFilter == 'ALL',
            color: const Color(0xFF25D366),
            onTap: () => onApplyFilter(filterType: 'ALL', countryCode: null),
          ),
          if (selectedCountryCode != null) ...[
            const SizedBox(width: 6),
            FeedFilterChip(
              label: '📍 Mon pays',
              isSelected: currentFilter == 'COUNTRY',
              color: Colors.blue,
              onTap: () => onApplyFilter(
                  filterType: 'COUNTRY', countryCode: selectedCountryCode),
            ),
            const SizedBox(width: 6),
            FeedFilterChip(
              label: '🔄 Mix',
              isSelected: currentFilter == 'MIXED',
              color: Colors.purple,
              onTap: () => onApplyFilter(
                  filterType: 'MIXED', countryCode: selectedCountryCode),
            ),
          ],
          if (trailingChildren.isNotEmpty) ...[
            const SizedBox(width: 10),
            Center(child: Container(width: 1, height: 16, color: Colors.grey[700])),
            const SizedBox(width: 10),
            ...trailingChildren,
          ],
        ],
      ),
    );
  }
}

/// Chip individuelle du filtre.
class FeedFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const FeedFilterChip({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[800],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? Colors.white.withAlpha(60) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[300],
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
