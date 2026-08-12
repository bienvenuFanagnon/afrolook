import 'package:flutter/material.dart';
import '../constants/user_interests.dart';
import '../theme/app_colors.dart';

class InterestsSelectorWidget extends StatefulWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final int minRequired;
  final bool compact;

  const InterestsSelectorWidget({
    Key? key,
    required this.selected,
    required this.onChanged,
    this.minRequired = 3,
    this.compact = false,
  }) : super(key: key);

  @override
  State<InterestsSelectorWidget> createState() => _InterestsSelectorWidgetState();
}

class _InterestsSelectorWidgetState extends State<InterestsSelectorWidget> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  void _toggle(String categoryId) {
    setState(() {
      if (_selected.contains(categoryId)) {
        _selected.remove(categoryId);
      } else {
        _selected.add(categoryId);
      }
    });
    widget.onChanged(List.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = colors.isDark;
    final ok = _selected.length >= widget.minRequired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(
                'Centres d\'intérêt',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ok
                      ? colors.primary.withValues(alpha: 0.15)
                      : colors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_selected.length} / min ${widget.minRequired}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ok ? colors.primary : colors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: UserInterests.categories.map((cat) {
            final isSelected = _selected.contains(cat.id);
            final catColor = UserInterests.categoryColor(cat.id, isDark: isDark);
            return GestureDetector(
              onTap: () => _toggle(cat.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? 10 : 14,
                  vertical: widget.compact ? 6 : 9,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? catColor : catColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? catColor : catColor.withValues(alpha: 0.30),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      cat.emoji,
                      style: TextStyle(fontSize: widget.compact ? 13 : 15),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat.labelFr,
                      style: TextStyle(
                        fontSize: widget.compact ? 12 : 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : catColor,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.check, size: 13, color: Colors.white),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// Widget d'affichage (lecture seule)
class InterestsDisplayWidget extends StatelessWidget {
  final List<String> codes;
  final bool compact;

  const InterestsDisplayWidget({
    Key? key,
    required this.codes,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cats = codes
        .map((id) => UserInterests.categoryById(id))
        .whereType<InterestCategory>()
        .toList();
    if (cats.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: cats.map((cat) {
        final catColor = UserInterests.categoryColor(cat.id, isDark: colors.isDark);
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: catColor.withValues(alpha: 0.30), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(cat.emoji, style: TextStyle(fontSize: compact ? 12 : 14)),
              const SizedBox(width: 5),
              Text(
                cat.labelFr,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: catColor,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
