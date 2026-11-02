import 'package:afrotok/l10n/tr.dart';
import 'package:flutter/material.dart';

import '../../models/model_data.dart';
import '../../theme/app_colors.dart';
import '../../services/api/api_identity.dart';
import '../../services/api/shop_api.dart';
import '../LiveAgora/create_live_page.dart';

/// Entrée « Vente en direct » du menu : vérifie que la personne a une entreprise, charge SES articles puis ouvre le choix des articles à vendre.
/// (L'administration de la vente en direct n'est PAS ici : elle est dans le hub d'administration, réservé à l'équipe.)
Future<void> startMyShoppingLive(BuildContext context) async {
  void say(String m) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  try {
    final business = await ShopApi.businesses(mine: true);
    if (business.isEmpty) {
      say(tr("Crée d'abord ton entreprise (Boutique, puis Ma boutique) pour vendre en direct."));
      return;
    }
    final mine = await ShopApi.articles(ownerId: ApiIdentity.myId!, limit: 50);
    if (context.mounted) await startShoppingLive(context, mine.items);
  } catch (_) {
    say(tr('Impossible de charger tes produits pour le moment.'));
  }
}

/// Vente en direct depuis la boutique : le vendeur coche les articles à vendre, puis la page de création du live s'ouvre déjà sur « Vente en direct »
/// (les articles choisis sont épinglés dès le début du live).
Future<void> startShoppingLive(BuildContext context, List<ArticleData> articles) async {
  final available = articles.where((p) => p.id != null).toList();
  if (available.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("Ajoute d'abord au moins un produit à ta boutique."))));
    return;
  }
  final c = AppColors.of(context);
  final chosen = <String>{};
  final ids = await showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Vente en direct', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(tr("Choisis les articles à vendre pendant le live. Les spectateurs les achètent en un clic ou négocient ; leur argent est protégé jusqu'à la réception, ce qui les rassure et fait vendre plus."),
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4)),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final p in available)
                  CheckboxListTile(
                    value: chosen.contains(p.id),
                    onChanged: (v) => set(() => v == true ? chosen.add(p.id!) : chosen.remove(p.id)),
                    activeColor: c.primary,
                    title: Text(p.titre ?? 'Produit', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary)),
                    subtitle: Text('${p.prix ?? 0} F', style: TextStyle(color: c.textSecondary)),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: chosen.isEmpty ? null : () => Navigator.pop(ctx, available.where((p) => chosen.contains(p.id)).map((p) => p.id!).toList()),
                  child: Text(chosen.isEmpty ? tr('Choisis au moins un article') : 'Continuer avec ${chosen.length} article(s)'),
                ),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
  if (ids == null || ids.isEmpty || !context.mounted) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => CreateLivePage(initialShopping: true, articleIds: ids)));
}
