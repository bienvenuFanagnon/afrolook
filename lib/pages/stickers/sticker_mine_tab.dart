import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/stickers/sticker_models.dart';
import '../../services/stickers/sticker_service.dart';
import '../../theme/app_colors.dart';
import 'create_sticker_page.dart';
import 'sticker_widgets.dart';

/// Onglet « Mes stickers » : bibliothèque personnelle, compteur « 3 / 10 », création et suppression.
class StickerMineTab extends StatefulWidget {
  final String userId;

  /// Raison qui empêche d'envoyer (abonnement, limites) : la grille est alors grisée.
  final String? blockedReason;
  final ValueChanged<StickerItem> onPick;

  const StickerMineTab({super.key, required this.userId, required this.blockedReason, required this.onPick});

  @override
  State<StickerMineTab> createState() => _StickerMineTabState();
}

class _StickerMineTabState extends State<StickerMineTab> with AutomaticKeepAliveClientMixin {
  final StickerService _service = StickerService.instance;
  List<StickerItem> _items = [];
  bool _loading = true;
  bool _failed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final list = await _service.loadUserStickers(widget.userId);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  int get _quota => StickerService.personalQuota(Provider.of<UserAuthProvider>(context, listen: false).loginUserData);

  Future<void> _create() async {
    if (_quota <= 0) {
      await showStickerPremiumInvite(context);
      return;
    }
    if (_items.length >= _quota) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Quota atteint : supprime un sticker pour en créer un autre'))),
      );
      return;
    }
    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const CreateStickerPage()));
    if (added == true && mounted) _load();
  }

  Future<void> _delete(StickerItem s) async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(context.tr('Supprimer ce sticker ?'),
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        content: Row(
          children: [
            SizedBox(width: 64, height: 64, child: StickerImage(sticker: s, loadAnimation: false)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(context.tr('Il sera retiré de Mes stickers. Les commentaires déjà publiés ne changent pas.'),
                  style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.35)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Annuler'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: c.danger, foregroundColor: Colors.white),
            child: Text(context.tr('Supprimer')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.deleteUserSticker(s);
      if (mounted) setState(() => _items = _items.where((e) => e.id != s.id).toList());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Suppression impossible. Vérifie ta connexion.'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    final quota = _quota;
    final blocked = widget.blockedReason != null;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  quota > 0
                      ? context.tr('Mes stickers {a} / {b}', {'a': _items.length, 'b': quota})
                      : context.tr('Mes stickers'),
                  style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: c.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: _create,
                icon: const Icon(Icons.add_reaction_outlined, size: 17),
                label: Text(context.tr('Créer un sticker'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        if (quota > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(context.tr('Touche pour envoyer · Appui long pour supprimer'),
                  style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            ),
          ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2.5))
              : _failed
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(context.tr('Impossible de charger tes stickers.'), style: TextStyle(color: c.textSecondary, fontSize: 13)),
                        TextButton(onPressed: _load, child: Text(context.tr('Réessayer'), style: TextStyle(color: c.primary))),
                      ]),
                    )
                  : _items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_reaction_outlined, size: 44, color: c.textSecondary.withOpacity(0.6)),
                                const SizedBox(height: 10),
                                Text(
                                  quota > 0
                                      ? context.tr('Tu n\'as pas encore de sticker perso')
                                      : context.tr('Crée tes propres stickers avec Premium'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: c.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(context.tr('Une image, un GIF ou une vidéo de 3 secondes maximum.'),
                                    textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                              ],
                            ),
                          ),
                        )
                      : Opacity(
                          opacity: blocked ? 0.4 : 1,
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
                            cacheExtent: 60,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                            itemCount: _items.length,
                            itemBuilder: (_, i) {
                              final s = _items[i];
                              return GestureDetector(
                                onTap: blocked ? null : () => widget.onPick(s),
                                onLongPress: () => _delete(s),
                                child: Container(
                                  decoration: BoxDecoration(color: c.surfaceVariant.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.all(4),
                                  child: StickerImage(sticker: s, loadAnimation: !blocked),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}
