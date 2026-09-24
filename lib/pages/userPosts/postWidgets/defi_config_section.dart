import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/model_data.dart';
import '../../defi/defi_info_page.dart';

/// Widget de configuration d'un DÉFI.
/// Gère son propre état et remonte le [DefiConfig] via [onChanged].
/// Passer null à [onChanged] indique une config invalide.
class DefiConfigSection extends StatefulWidget {
  final void Function(DefiConfig? config) onChanged;

  const DefiConfigSection({super.key, required this.onChanged});

  @override
  State<DefiConfigSection> createState() => _DefiConfigSectionState();
}

class _DefiConfigSectionState extends State<DefiConfigSection> {
  static const Color _yellow = Color(0xFFFFE14D);
  static const Color _darkBg = Color(0xFF1A1A1A);
  static const Color _inputBg = Color(0xFF2A2A2A);
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFFAAAAAA);
  static const Color _borderColor = Color(0xFF3A3A3A);

  final _cagnotteCtrl = TextEditingController();
  final _participationCtrl = TextEditingController(text: '0');
  final _voteCtrl = TextEditingController(text: '0');

  DateTime? _endDate;
  int _winnersCount = 1;

  @override
  void dispose() {
    _cagnotteCtrl.dispose();
    _participationCtrl.dispose();
    _voteCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    final cagnotte = int.tryParse(_cagnotteCtrl.text) ?? 0;
    final participation = int.tryParse(_participationCtrl.text) ?? 0;
    final vote = int.tryParse(_voteCtrl.text) ?? 0;

    // Validation minimale
    if (_endDate == null || cagnotte < 0) {
      widget.onChanged(null);
      return;
    }
    if (vote > 0 && vote < 5) {
      widget.onChanged(null);
      return;
    }

    widget.onChanged(DefiConfig(
      cagnottePieces: cagnotte,
      participationFee: participation,
      voteFee: vote,
      winnersCount: _winnersCount,
      rewardSplit: _defaultSplit(_winnersCount),
      endDate: _endDate!.millisecondsSinceEpoch,
      status: 'en_cours',
    ));
  }

  List<int> _defaultSplit(int n) {
    switch (n) {
      case 2: return [70, 30];
      case 3: return [60, 30, 10];
      default: return [100];
    }
  }

  String _splitLabel(int n) {
    switch (n) {
      case 2: return '1er: 70% • 2e: 30%';
      case 3: return '1er: 60% • 2e: 30% • 3e: 10%';
      default: return '1er: 100%';
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: _yellow,
            onPrimary: Colors.black,
            surface: const Color(0xFF1A1A1A),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
      _notify();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _darkBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _yellow.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: _yellow, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Configuration du Défi',
                  style: TextStyle(
                    color: _yellow,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DefiInfoPage()),
                  ),
                  child: Text(
                    'En savoir plus',
                    style: TextStyle(
                      color: _yellow.withOpacity(0.8),
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Lance un défi et laisse la communauté concourir pour ta cagnotte.',
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0x33FFE14D), height: 1),
          const SizedBox(height: 12),

          // ── Champs ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date de fin
                _label('Date de fin du défi *'),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickEndDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _endDate == null ? _borderColor : _yellow.withOpacity(0.7),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: _yellow, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _endDate == null
                              ? 'Choisir une date'
                              : '${_endDate!.day.toString().padLeft(2, '0')}/${_endDate!.month.toString().padLeft(2, '0')}/${_endDate!.year}',
                          style: TextStyle(
                            color: _endDate == null ? _textSecondary : _textPrimary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Cagnotte initiale
                _label('Cagnotte de départ (Afrcoins) *'),
                const SizedBox(height: 6),
                _buildNumberField(
                  controller: _cagnotteCtrl,
                  hint: 'Ex : 500',
                  suffix: '🪙',
                  onChange: (_) => _notify(),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Débité immédiatement de ton solde lors de la création.',
                    style: TextStyle(color: _textSecondary, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 14),

                // Frais de participation
                _label('Frais de participation (0 = gratuit)'),
                const SizedBox(height: 6),
                _buildNumberField(
                  controller: _participationCtrl,
                  hint: '0',
                  suffix: '🪙',
                  onChange: (_) => _notify(),
                ),
                const SizedBox(height: 14),

                // Frais de vote
                _label('Frais de vote (0 = gratuit, min 5)'),
                const SizedBox(height: 6),
                _buildNumberField(
                  controller: _voteCtrl,
                  hint: '0',
                  suffix: '🪙',
                  onChange: (_) {
                    final v = int.tryParse(_voteCtrl.text) ?? 0;
                    if (v > 0 && v < 5) {
                      // Snap to minimum
                    }
                    _notify();
                  },
                ),
                if ((int.tryParse(_voteCtrl.text) ?? 0) > 0 &&
                    (int.tryParse(_voteCtrl.text) ?? 0) < 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Minimum 5 Afrcoins par vote.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 14),

                // Nombre de gagnants
                _label('Nombre de gagnants'),
                const SizedBox(height: 8),
                Row(
                  children: [1, 2, 3].map((n) {
                    final selected = n == _winnersCount;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _winnersCount = n);
                          _notify();
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: selected ? _yellow : _inputBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? _yellow : _borderColor,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$n',
                              style: TextStyle(
                                color: selected ? Colors.black : _textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                Text(
                  _splitLabel(_winnersCount),
                  style: TextStyle(color: _yellow.withOpacity(0.8), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  "L'app prend 30% de chaque paiement (arrondi à l'entier supérieur).",
                  style: TextStyle(color: _textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
      );

  Widget _buildNumberField({
    required TextEditingController controller,
    required String hint,
    required String suffix,
    required void Function(String) onChange,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(color: _textPrimary, fontSize: 14),
        onChanged: onChange,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textSecondary),
          suffixText: suffix,
          suffixStyle: const TextStyle(fontSize: 16),
          filled: true,
          fillColor: _inputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderColor)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borderColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _yellow)),
        ),
      );
}
