import 'package:flutter/material.dart';

/// Barre de filtres pays réutilisable (Tous / Mon pays / Mix / Autre).
class FeedFilterBar extends StatelessWidget {
  final String currentFilter;
  final String? selectedCountryCode;
  final void Function({required String filterType, String? countryCode}) onApplyFilter;
  final VoidCallback onShowCountryModal;

  const FeedFilterBar({
    Key? key,
    required this.currentFilter,
    required this.selectedCountryCode,
    required this.onApplyFilter,
    required this.onShowCountryModal,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FeedFilterChip(
              label: '🌍 Tous',
              isSelected: currentFilter == 'ALL',
              color: const Color(0xFF25D366),
              onTap: () => onApplyFilter(filterType: 'ALL', countryCode: null),
            ),
            const SizedBox(width: 8),
            if (selectedCountryCode != null) ...[
              FeedFilterChip(
                label: '📍 Mon pays $selectedCountryCode',
                isSelected: currentFilter == 'COUNTRY',
                color: Colors.blue,
                onTap: () => onApplyFilter(
                    filterType: 'COUNTRY', countryCode: selectedCountryCode),
              ),
              const SizedBox(width: 8),
              FeedFilterChip(
                label: '🔄 Mix',
                isSelected: currentFilter == 'MIXED',
                color: Colors.purple,
                onTap: () => onApplyFilter(
                    filterType: 'MIXED', countryCode: selectedCountryCode),
              ),
              const SizedBox(width: 8),
            ],
            FeedFilterChip(
              label: '⚙️ Autre',
              isSelected: currentFilter == 'CUSTOM',
              color: Colors.orange,
              onTap: onShowCountryModal,
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
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
