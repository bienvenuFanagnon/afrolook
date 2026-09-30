import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/coin_checkout.dart';
import '../../services/stickers/sticker_models.dart';
import '../../services/stickers/sticker_service.dart';
import '../../theme/app_colors.dart';
import 'sticker_widgets.dart';

/// Onglet « Cadeaux » : stickers-cadeaux (packs actifs, `giftPriceCoins > 0`) avec leur prix en pièces.
class StickerGiftTab extends StatefulWidget {
  /// Commentaire à qui l'on offre ; null quand le sélecteur n'est pas ouvert depuis un commentaire.
  final StickerGiftTarget? target;
  final ValueChanged<StickerItem> onGift;

  const StickerGiftTab({super.key, required this.target, required this.onGift});

  @override
  State<StickerGiftTab> createState() => _StickerGiftTabState();
}

class _StickerGiftTabState extends State<StickerGiftTab> with AutomaticKeepAliveClientMixin {
  List<StickerItem> _items = [];
  bool _loading = true;
  bool _failed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final cached = StickerService.instance.cachedGiftStickers;
    if (cached != null) {
      _items = cached;
      _loading = false;
    }
    _load(silent: cached != null);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final list = await StickerService.instance.loadGiftStickers();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              Icon(Icons.card_giftcard_rounded, size: 16, color: kStickerGold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.target != null
                      ? context.tr('Choisis le sticker à offrir')
                      : context.tr('Ouvre le menu cadeau depuis un commentaire'),
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2.5))
              : _failed
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(context.tr('Impossible de charger les stickers.'), style: TextStyle(color: c.textSecondary, fontSize: 13)),
                        TextButton(onPressed: _load, child: Text(context.tr('Réessayer'), style: TextStyle(color: c.primary))),
                      ]),
                    )
                  : _items.isEmpty
                      ? Center(child: Text(context.tr('Aucun sticker-cadeau pour le moment'), style: TextStyle(color: c.textSecondary, fontSize: 13)))
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
                          cacheExtent: 60,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.78,
                          ),
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final s = _items[i];
                            final caption = StickerService.instance.captionFor(s, lang);
                            return GestureDetector(
                              onTap: () {
                                if (widget.target == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(context.tr('Ouvre le menu cadeau depuis un commentaire'))),
                                  );
                                  return;
                                }
                                widget.onGift(s);
                              },
                              child: Container(
                                decoration: BoxDecoration(color: c.surfaceVariant.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                                child: Column(
                                  children: [
                                    Expanded(child: Center(child: StickerImage(sticker: s, loadAnimation: false))),
                                    if (caption != null)
                                      Text(caption,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: c.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w600)),
                                    Text('${CoinCheckout.fmt(s.giftPriceCoins)} 🪙',
                                        style: const TextStyle(color: kStickerGold, fontSize: 11.5, fontWeight: FontWeight.w900)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
