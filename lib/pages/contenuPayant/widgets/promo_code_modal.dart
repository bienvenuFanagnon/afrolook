import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PromoCodeModal extends StatefulWidget {
  final ContentPaie content;
  final void Function(PromoCode code) onApplied;

  const PromoCodeModal({
    Key? key,
    required this.content,
    required this.onApplied,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context,
    ContentPaie content,
    void Function(PromoCode code) onApplied,
  ) {
    return showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PromoCodeModal(content: content, onApplied: onApplied),
    );
  }

  @override
  State<PromoCodeModal> createState() => _PromoCodeModalState();
}

class _PromoCodeModalState extends State<PromoCodeModal> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  PromoCode? _validCode;
  String? _errorMsg;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _checkCode() async {
    final input = _ctrl.text.trim().toUpperCase();
    if (input.isEmpty) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
      _validCode = null;
    });

    try {
      // L'API n'a pas (encore) de vérification d'un code par l'acheteur (voir lacunes_api_canaux.md) : le code est gardé tel quel et ENVOYÉ avec
      // l'achat ; le serveur calcule le prix et ignore un code invalide (prix normal). La réduction exacte n'est donc pas affichée ici.
      if (widget.content.id == null) {
        setState(() => _errorMsg = 'Contenu introuvable');
        return;
      }
      setState(() => _validCode = PromoCode(
            creatorId: widget.content.ownerId,
            contentId: widget.content.id,
            code: input,
            type: 'percent',
            value: 0,
          ));
    } catch (e) {
      setState(() => _errorMsg = 'Une erreur est survenue. Réessaie.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply() {
    if (_validCode == null) return;
    widget.onApplied(_validCode!);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final original = widget.content.effectivePrice;
    final discounted = _validCode != null
        ? _validCode!.discountedPrice(original)
        : original;
    final saving = original - discounted;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.local_offer_outlined,
                  color: const Color(0xFF25D366), size: 20),
              const SizedBox(width: 8),
              Text(
                'Code promo',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: 'Ex: KOFI20, DESIGN10...',
                    hintStyle: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        letterSpacing: 0),
                    filled: true,
                    fillColor: colors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: colors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF25D366), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                  ),
                  onSubmitted: (_) => _checkCode(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _loading ? null : _checkCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Vérifier',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Error
          if (_errorMsg != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text(_errorMsg!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.red)),
                ],
              ),
            ),

          // Valid code
          if (_validCode != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF25D366).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Color(0xFF25D366), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Code ${_validCode!.code} valide !',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF25D366)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prix original',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: colors.textSecondary)),
                            Text(
                              '${original.toInt()} F',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.textSecondary,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward,
                          color: colors.textSecondary, size: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _validCode!.type == 'percent'
                                  ? '–${_validCode!.value.toInt()}%'
                                  : '–${_validCode!.value.toInt()} F',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF25D366),
                                  fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '${discounted.toInt()} F',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFD400),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (saving > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Vous économisez ${saving.toInt()} F',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD400),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Payer ${discounted.toInt()} F avec ce code',
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
