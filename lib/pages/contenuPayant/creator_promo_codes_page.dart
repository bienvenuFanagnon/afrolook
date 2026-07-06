import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart' show UserAuthProvider;
import 'package:afrotok/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CreatorPromoCodesPage extends StatefulWidget {
  final ContentPaie content;

  const CreatorPromoCodesPage({Key? key, required this.content})
      : super(key: key);

  @override
  State<CreatorPromoCodesPage> createState() => _CreatorPromoCodesPageState();
}

class _CreatorPromoCodesPageState extends State<CreatorPromoCodesPage> {
  late AppColors _colors;

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final auth = context.read<UserAuthProvider>();
    final uid = auth.loginUserData.id ?? '';

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.surface,
        title: Text('Codes promo', style: TextStyle(color: _colors.textPrimary)),
        iconTheme: IconThemeData(color: _colors.textPrimary),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _showCreateSheet(context, uid),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Créer'),
            style: TextButton.styleFrom(foregroundColor: _colors.primary),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('PromoCodes')
            .where('creatorId', isEqualTo: uid)
            .where('contentId', isEqualTo: widget.content.id)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: _colors.primary));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _buildEmpty();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              data['id'] = docs[i].id;
              final code = PromoCode.fromJson(data);
              return _PromoCodeTile(
                  code: code,
                  colors: _colors,
                  contentPrice: widget.content.effectivePrice);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.discount_outlined, size: 60, color: _colors.textSecondary),
          const SizedBox(height: 12),
          Text('Aucun code promo',
              style: TextStyle(
                  color: _colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Crée un code pour offrir des réductions sur ce contenu.',
              style: TextStyle(color: _colors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showCreateSheet(
                context, context.read<UserAuthProvider>().loginUserData.id ?? ''),
            icon: const Icon(Icons.add),
            label: const Text('Créer un code promo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _colors.primary,
              foregroundColor: _colors.onPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateSheet(BuildContext context, String uid) {
    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreatePromoSheet(
        content: widget.content,
        creatorId: uid,
        colors: _colors,
      ),
    );
  }
}

// ─── Tile d'un code existant ─────────────────────────────────────────────────

class _PromoCodeTile extends StatelessWidget {
  final PromoCode code;
  final AppColors colors;
  final double contentPrice;

  const _PromoCodeTile(
      {required this.code,
      required this.colors,
      required this.contentPrice});

  @override
  Widget build(BuildContext context) {
    final statusColor = code.isValid
        ? Colors.green
        : code.isExpired
            ? Colors.orange
            : Colors.red;
    final statusLabel = code.isValid
        ? 'Actif'
        : code.isExpired
            ? 'Expiré'
            : code.isMaxedOut
                ? 'Épuisé'
                : 'Inactif';

    final discounted = code.discountedPrice(contentPrice);
    final discountLabel = code.type == 'percent'
        ? '−${code.value.toInt()}%'
        : '−${code.value.toInt()} FCFA';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.textSecondary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // code pill
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code.code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Code copié !'),
                        duration: Duration(seconds: 1)),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(code.code,
                          style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 1.2)),
                      const SizedBox(width: 6),
                      Icon(Icons.copy_outlined,
                          size: 14, color: colors.primary),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // badge statut
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // réduction + prix final
          Row(
            children: [
              _InfoChip(
                  icon: Icons.discount_outlined,
                  label: discountLabel,
                  color: colors.primary),
              const SizedBox(width: 8),
              _InfoChip(
                  icon: Icons.price_check_outlined,
                  label: '→ ${discounted.toInt()} FCFA',
                  color: colors.textSecondary),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.bar_chart_outlined,
                  size: 14, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                  '${code.usedCount} utilisation${code.usedCount > 1 ? 's' : ''}'
                  '${code.maxUses != null ? ' / ${code.maxUses}' : ''}',
                  style:
                      TextStyle(color: colors.textSecondary, fontSize: 12)),
              if (code.expiresAt != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.access_time_outlined,
                    size: 14, color: colors.textSecondary),
                const SizedBox(width: 4),
                Builder(builder: (_) {
                  final dt = DateTime.fromMillisecondsSinceEpoch(
                      code.expiresAt!);
                  return Text(
                      'expire le ${dt.day}/${dt.month}/${dt.year}',
                      style: TextStyle(
                          color: colors.textSecondary, fontSize: 12));
                }),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // toggle actif/inactif
              if (!code.isExpired && !code.isMaxedOut)
                TextButton(
                  onPressed: () => _toggleActive(code),
                  style: TextButton.styleFrom(
                      foregroundColor:
                          code.isActive ? Colors.orange : Colors.green),
                  child: Text(code.isActive ? 'Désactiver' : 'Réactiver'),
                ),
              TextButton(
                onPressed: () => _confirmDelete(context, code),
                style:
                    TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(PromoCode code) async {
    if (code.id == null) return;
    await FirebaseFirestore.instance
        .collection('PromoCodes')
        .doc(code.id)
        .update({'isActive': !code.isActive});
  }

  Future<void> _confirmDelete(BuildContext context, PromoCode code) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce code ?'),
        content: Text('Le code "${code.code}" sera définitivement supprimé.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok == true && code.id != null) {
      await FirebaseFirestore.instance
          .collection('PromoCodes')
          .doc(code.id)
          .delete();
    }
  }
}

// ─── Chip d'info ──────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}

// ─── Sheet de création ────────────────────────────────────────────────────────

class _CreatePromoSheet extends StatefulWidget {
  final ContentPaie content;
  final String creatorId;
  final AppColors colors;

  const _CreatePromoSheet(
      {required this.content,
      required this.creatorId,
      required this.colors});

  @override
  State<_CreatePromoSheet> createState() => _CreatePromoSheetState();
}

class _CreatePromoSheetState extends State<_CreatePromoSheet> {
  final _codeCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _maxUsesCtrl = TextEditingController();
  String _type = 'percent'; // percent | fixed
  DateTime? _expiresAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    _maxUsesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: c.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Nouveau code promo',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Pour : ${widget.content.title}',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),

          // Code
          TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: c.textPrimary, letterSpacing: 1.5),
            decoration: _inputDeco(c, 'Code (ex: PROMO20)', Icons.label_outline),
          ),
          const SizedBox(height: 12),

          // Type selector
          Row(
            children: [
              Text('Type :', style: TextStyle(color: c.textSecondary)),
              const SizedBox(width: 12),
              _TypeButton(
                  label: '% Pourcentage',
                  selected: _type == 'percent',
                  colors: c,
                  onTap: () => setState(() => _type = 'percent')),
              const SizedBox(width: 8),
              _TypeButton(
                  label: 'FCFA fixe',
                  selected: _type == 'fixed',
                  colors: c,
                  onTap: () => setState(() => _type = 'fixed')),
            ],
          ),
          const SizedBox(height: 12),

          // Valeur
          TextField(
            controller: _valueCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: c.textPrimary),
            decoration: _inputDeco(
                c,
                _type == 'percent' ? 'Valeur (ex: 20 pour −20%)' : 'Montant en FCFA',
                Icons.discount_outlined,
                suffix: _type == 'percent' ? '%' : 'FCFA'),
          ),
          const SizedBox(height: 12),

          // Max uses + expiration
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _maxUsesCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: c.textPrimary),
                  decoration: _inputDeco(
                      c, 'Limite (vide = illimité)', Icons.people_outline),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _pickExpiry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: c.textSecondary.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 16, color: c.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _expiresAt != null
                                ? '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                                : 'Expiration',
                            style: TextStyle(
                                color: _expiresAt != null
                                    ? c.textPrimary
                                    : c.textSecondary,
                                fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.primary,
                foregroundColor: c.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Créer le code',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(AppColors c, String label, IconData icon,
      {String? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: c.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, size: 18, color: c.textSecondary),
      suffixText: suffix,
      suffixStyle: TextStyle(color: c.textSecondary),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.textSecondary.withOpacity(0.4))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.primary)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _save() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final valueText = _valueCtrl.text.trim();

    if (code.isEmpty) {
      setState(() => _error = 'Le code est requis.');
      return;
    }
    if (code.length < 4) {
      setState(() => _error = 'Le code doit contenir au moins 4 caractères.');
      return;
    }
    final value = double.tryParse(valueText);
    if (value == null || value <= 0) {
      setState(() => _error = 'Entrez une valeur valide.');
      return;
    }
    if (_type == 'percent' && value > 100) {
      setState(() => _error = 'Le pourcentage ne peut pas dépasser 100.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // Vérifier unicité du code pour ce contenu + ce créateur
      final existing = await FirebaseFirestore.instance
          .collection('PromoCodes')
          .where('creatorId', isEqualTo: widget.creatorId)
          .where('contentId', isEqualTo: widget.content.id)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        setState(() {
          _error = 'Ce code existe déjà pour ce contenu.';
          _saving = false;
        });
        return;
      }

      final maxUses = int.tryParse(_maxUsesCtrl.text.trim());
      final data = PromoCode(
        creatorId: widget.creatorId,
        contentId: widget.content.id,
        code: code,
        type: _type,
        value: value,
        maxUses: maxUses,
        usedCount: 0,
        expiresAt:
            _expiresAt?.millisecondsSinceEpoch,
        isActive: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final ref = await FirebaseFirestore.instance
          .collection('PromoCodes')
          .add(data.toJson());

      // Enregistrer l'id dans le document
      await ref.update({'id': ref.id});

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Code "$code" créé avec succès !'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() {
        _error = 'Erreur : $e';
        _saving = false;
      });
    }
  }
}

class _TypeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _TypeButton(
      {required this.label,
      required this.selected,
      required this.colors,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withOpacity(0.12)
              : Colors.transparent,
          border: Border.all(
              color: selected ? colors.primary : colors.textSecondary.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? colors.primary : colors.textSecondary,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}
