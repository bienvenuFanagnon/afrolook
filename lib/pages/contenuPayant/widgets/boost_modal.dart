import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BoostModal extends StatefulWidget {
  final ContentPaie content;
  final bool isAdmin;

  const BoostModal({
    Key? key,
    required this.content,
    this.isAdmin = false,
  }) : super(key: key);

  static Future<void> show(
      BuildContext context, ContentPaie content,
      {bool isAdmin = false}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          BoostModal(content: content, isAdmin: isAdmin),
    );
  }

  @override
  State<BoostModal> createState() => _BoostModalState();
}

class _BoostModalState extends State<BoostModal> {
  int _selectedDays = 14;
  bool _loading = false;

  static const Map<int, String> _labels = {
    7: '1 sem',
    14: '2 sem',
    30: '1 mois',
    90: '3 mois',
    180: '6 mois',
    365: '12 mois',
  };

  Map<int, int> get _prices {
    return {7: 1000, 14: 1800, 30: 3500, 90: 9000, 180: 16000, 365: 28000};
  }

  String _discount(int days) {
    final basePerDay = _prices[7]! / 7;
    final myPrice = _prices[days] ?? 0;
    final myPerDay = myPrice / days;
    if (myPerDay >= basePerDay) return '';
    final pct = (((basePerDay - myPerDay) / basePerDay) * 100).round();
    return '–$pct%';
  }

  Future<void> _confirm() async {
    setState(() => _loading = true);
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    final uid = authProvider.userData?.id;
    if (uid == null || widget.content.id == null) {
      setState(() => _loading = false);
      return;
    }

    final price = widget.isAdmin ? 0 : (_prices[_selectedDays] ?? 0);
    final now = DateTime.now().millisecondsSinceEpoch;
    final endDate = now + (_selectedDays * 24 * 60 * 60 * 1000);

    try {
      await FirebaseFirestore.instance
          .collection('ContentPaies')
          .doc(widget.content.id)
          .update({
        'isBoosted': true,
        'boostStartDate': now,
        'boostEndDate': endDate,
        'boostDurationDays': _selectedDays,
        'boostAmountPaid': price.toDouble(),
        'boostedByAdmin': widget.isAdmin,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isAdmin
                ? 'Contenu boosté gratuitement !'
                : 'Contenu boosté pendant ${_labels[_selectedDays]} !'),
            backgroundColor: const Color(0xFF25D366),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final prices = _prices;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: colors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bolt, color: const Color(0xFFFFD400), size: 22),
              const SizedBox(width: 6),
              Text(
                widget.isAdmin ? 'Booster (admin — gratuit)' : 'Booster ce contenu',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Votre contenu sera mis en avant dans toutes les sections',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            'DURÉE DU BOOST',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: colors.textSecondary),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _labels.entries.map((e) {
                final days = e.key;
                final label = e.value;
                final price = prices[days] ?? 0;
                final discount = _discount(days);
                final isSelected = _selectedDays == days;
                final isPopular = days == 30;

                return GestureDetector(
                  onTap: () => setState(() => _selectedDays = days),
                  child: Container(
                    width: 78,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isPopular
                              ? const Color(0xFF25D366).withOpacity(0.12)
                              : const Color(0xFFFFD400).withOpacity(0.12))
                          : colors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? (isPopular
                                ? const Color(0xFF25D366)
                                : const Color(0xFFFFD400))
                            : colors.divider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (isPopular)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF25D366),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '⭐ POP',
                              style: TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white),
                            ),
                          ),
                        Text(
                          label,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: colors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isAdmin
                              ? 'Gratuit'
                              : '${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ')} F',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFFFD400)),
                        ),
                        if (discount.isNotEmpty)
                          Text(
                            discount,
                            style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF25D366)),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          if (!widget.isAdmin)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    '${_labels[_selectedDays]} · ',
                    style: TextStyle(
                        fontSize: 11, color: colors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    widget.isAdmin
                        ? 'Gratuit'
                        : '−${prices[_selectedDays] ?? 0} F de votre solde',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFFD400)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _confirm,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.bolt, color: Colors.black, size: 18),
              label: Text(
                widget.isAdmin
                    ? 'Booster gratuitement'
                    : 'Confirmer — ${prices[_selectedDays] ?? 0} F',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD400),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Boost activé immédiatement · Non remboursable',
            style:
                TextStyle(fontSize: 9, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
