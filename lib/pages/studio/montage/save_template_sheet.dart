import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';
import '../../../models/community_template.dart';
import '../../../services/api/community_templates_api.dart';
import '../../../theme/app_colors.dart';
import '../studio_theme.dart';

AppColors get _c => studioColors;

/// « Enregistrer comme modèle » (09/11/2026) : la personne nomme son montage, choisit une catégorie et un prix en pièces (gratuit, 10, 20, 30 ou 50), puis l'envoie à l'équipe.
/// Le modèle est publié tout de suite, sans validation préalable ; l'équipe peut le retirer. Aucun pourcentage n'est affiché : la personne voit seulement ses gains en pièces dans « Mes modèles ».
/// Rend le modèle créé (déjà publié, sans validation préalable), ou null si la personne a fermé la feuille.
Future<CommunityTemplate?> showSaveTemplateSheet(BuildContext context, {required Map<String, dynamic> recipe, String suggestedName = ''}) {
  return showModalBottomSheet<CommunityTemplate>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SaveTemplateSheet(recipe: recipe, suggestedName: suggestedName),
    ),
  );
}

class SaveTemplateSheet extends StatefulWidget {
  const SaveTemplateSheet({super.key, required this.recipe, this.suggestedName = ''});
  final Map<String, dynamic> recipe;
  final String suggestedName;

  @override
  State<SaveTemplateSheet> createState() => _SaveTemplateSheetState();
}

class _SaveTemplateSheetState extends State<SaveTemplateSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.suggestedName);
  String _category = 'fun';
  int _price = 0;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().length >= 3;

  Future<void> _send() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final t = await CommunityTemplatesApi.create(name: _name.text.trim(), category: _category, priceCoins: _price, recipe: widget.recipe);
      if (mounted) Navigator.pop(context, t);
    } catch (e) {
      // le message du serveur est déjà en français (« Tu as déjà 10 modèles en attente… », recette refusée…)
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '${(e as dynamic).message ?? e}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('save_template_sheet'),
      decoration: BoxDecoration(color: _c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: _c.border, borderRadius: BorderRadius.circular(3)))),
          const SizedBox(height: 12),
          Text(context.tr('Enregistrer comme modèle'), style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            context.tr('Les autres pourront refaire ce montage avec leurs propres photos et vidéos. Ton modèle est publié tout de suite ; l\'équipe peut le retirer s\'il ne respecte pas les règles.'),
            style: TextStyle(color: _c.textSecondary, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('template_name'),
            controller: _name,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: _c.textPrimary),
            decoration: InputDecoration(labelText: context.tr('Nom du modèle'), counterText: '', border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Text(context.tr('Catégorie'), style: TextStyle(color: _c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in kCommunityCategories.entries)
              ChoiceChip(
                key: ValueKey('template_cat_${e.key}'),
                label: Text(context.tr(e.value)),
                selected: _category == e.key,
                onSelected: (_) => setState(() => _category = e.key),
              ),
          ]),
          const SizedBox(height: 14),
          Text(context.tr('Prix pour les autres'), style: TextStyle(color: _c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in kCommunityPrices)
              ChoiceChip(
                key: ValueKey('template_price_$p'),
                label: Text(p == 0 ? context.tr('Gratuit') : context.tr('{n} pièces', {'n': '$p'})),
                selected: _price == p,
                onSelected: (_) => setState(() => _price = p),
              ),
          ]),
          if (_price > 0) ...[
            const SizedBox(height: 6),
            Text(context.tr('Tu reçois des pièces gagnées à chaque utilisation. Tu les suis dans « Mes modèles ».'), style: TextStyle(color: _c.textSecondary, fontSize: 12)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, key: const ValueKey('template_error'), style: TextStyle(color: _c.danger, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('template_send'),
              onPressed: _valid && !_busy ? _send : null,
              style: FilledButton.styleFrom(backgroundColor: _c.accent, foregroundColor: _c.onAccent, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _busy
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _c.onAccent))
                  : Text(context.tr('Publier mon modèle'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
