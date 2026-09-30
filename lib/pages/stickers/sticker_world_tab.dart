import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/coin_checkout.dart';
import '../../services/stickers/sticker_models.dart';
import '../../services/stickers/sticker_service.dart';
import '../../theme/app_colors.dart';
import 'sticker_pack_page.dart';
import 'sticker_studio_page.dart';
import 'sticker_widgets.dart';

String stickerRegionLabel(BuildContext context, String region) {
  switch (region) {
    case 'near': return context.tr('Près de chez moi');
    case 'africa': return context.tr('Afrique');
    case 'caribbean': return context.tr('Caraïbes');
    case 'europe': return context.tr('Europe');
    case 'asia': return context.tr('Asie');
    case 'latam': return context.tr('Amérique latine');
    case 'mena': return context.tr('Moyen-Orient');
    case 'universal': return context.tr('Monde');
    default: return context.tr('Tous');
  }
}

/// Prix d'un pack : « Gratuit » ou « N pièces ».
String stickerPackPriceText(BuildContext context, StickerPack p) =>
    p.isFree ? context.tr('Gratuit') : context.tr('{a} pièces', {'a': CoinCheckout.fmt(p.priceCoins)});

/// Ouvre la page d'un pack ; renvoie le sticker choisi (à envoyer) ou null.
Future<StickerItem?> openStickerPack(
  BuildContext context,
  StickerPack pack, {
  StickerCreatorInfo? creator,
  bool canSend = true,
}) {
  return Navigator.of(context).push<StickerItem>(
    MaterialPageRoute(builder: (_) => StickerPackPage(pack: pack, creator: creator, canSend: canSend)),
  );
}

/// Carte d'un pack : 4 miniatures, nom, créateur (badge vérifié), prix.
class StickerPackCard extends StatelessWidget {
  final StickerPack pack;
  final StickerCreatorInfo? creator;
  final bool owned;
  final VoidCallback onTap;

  const StickerPackCard({super.key, required this.pack, required this.creator, required this.owned, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final pseudo = creator?.pseudo ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.surfaceVariant.withOpacity(0.6), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            _Thumbs(pack: pack),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pack.localizedName(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(pseudo.isEmpty ? '' : '@$pseudo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: c.textSecondary, fontSize: 12)),
                      ),
                      if (creator?.verified == true) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: context.tr('Créateur vérifié'),
                          child: const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF1DA1F2)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(context.tr('{a} stickers', {'a': pack.stickerCount}),
                          style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                      const Spacer(),
                      _PriceTag(text: owned ? context.tr('Acheté') : stickerPackPriceText(context, pack), free: pack.isFree || owned),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final String text;
  final bool free;
  const _PriceTag({required this.text, required this.free});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = free ? c.success : kStickerGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _Thumbs extends StatelessWidget {
  final StickerPack pack;
  const _Thumbs({required this.pack});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      width: 76,
      height: 76,
      child: FutureBuilder<List<StickerItem>>(
        future: StickerService.instance.packPreview(pack.id),
        builder: (_, snap) {
          final items = snap.data ?? const <StickerItem>[];
          if (items.isEmpty) {
            return Container(
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.all(6),
              child: pack.coverUrl.isEmpty
                  ? Icon(Icons.sticky_note_2_outlined, color: c.textSecondary)
                  : Image.network(pack.coverUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
            );
          }
          return GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final s in items)
                Container(
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.all(2),
                  child: Image.network(s.thumbUrl,
                      fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Base commune des onglets « Monde » et « Créateurs » : chargement des packs, créateurs et achats.
abstract class _PackTabState<T extends StatefulWidget> extends State<T> with AutomaticKeepAliveClientMixin<T> {
  List<StickerPack> packs = [];
  List<StickerPack> ownedPacks = [];
  Set<String> ownedIds = {};
  Map<String, StickerCreatorInfo> creators = {};
  bool loading = true;
  bool failed = false;

  String get userId;
  bool get canSend;
  ValueChanged<StickerItem> get onPick;
  Future<List<StickerPack>> fetchPacks();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final list = await fetchPacks();
      final owned = await StickerService.instance.loadOwnedPackIds(userId);
      final ownedList = await StickerService.instance.loadPacksByIds(owned);
      final infos = await StickerService.instance.resolveCreators([
        ...list.map((p) => p.creatorId),
        ...ownedList.map((p) => p.creatorId),
      ]);
      if (!mounted) return;
      setState(() {
        packs = list;
        ownedIds = owned;
        ownedPacks = ownedList;
        creators = infos;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        failed = true;
      });
    }
  }

  Future<void> openPack(StickerPack p) async {
    final picked = await openStickerPack(context, p, creator: creators[p.creatorId], canSend: canSend);
    if (!mounted) return;
    if (picked != null) {
      onPick(picked);
    } else {
      // Un achat a pu avoir lieu dans la page du pack.
      final owned = await StickerService.instance.loadOwnedPackIds(userId);
      if (mounted && owned.length != ownedIds.length) setState(() => ownedIds = owned);
    }
  }

  Widget card(StickerPack p) => StickerPackCard(
        pack: p,
        creator: creators[p.creatorId],
        owned: ownedIds.contains(p.id),
        onTap: () => openPack(p),
      );

  Widget message(AppColors c, String text, {bool retry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(color: c.textSecondary, fontSize: 13)),
          if (retry) TextButton(onPressed: load, child: Text(context.tr('Réessayer'), style: TextStyle(color: c.primary))),
        ],
      ),
    );
  }
}

/// Onglet « Monde » : packs de créateurs et du monde, par région.
class StickerWorldTab extends StatefulWidget {
  final String userId;
  final bool canSend;
  final ValueChanged<StickerItem> onPick;

  const StickerWorldTab({super.key, required this.userId, required this.canSend, required this.onPick});

  @override
  State<StickerWorldTab> createState() => _StickerWorldTabState();
}

class _StickerWorldTabState extends _PackTabState<StickerWorldTab> {
  String _region = 'all'; // 'all', 'near' ou une région
  String? _userRegion;

  @override
  String get userId => widget.userId;
  @override
  bool get canSend => widget.canSend;
  @override
  ValueChanged<StickerItem> get onPick => widget.onPick;
  @override
  Future<List<StickerPack>> fetchPacks() => StickerService.instance.loadWorldPacks();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
    _userRegion = StickerService.regionForUser(user);
    if (_userRegion != null) _region = 'near';
  }

  List<StickerPack> get _visible {
    if (_region == 'all') return packs;
    final r = _region == 'near' ? _userRegion : _region;
    return packs.where((p) => p.region == r).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    final chips = <String>['all', if (_userRegion != null) 'near', ...kStickerRegions];
    final items = _visible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(context.tr('Découvrir le monde'),
                style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            itemCount: chips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final sel = chips[i] == _region;
              return GestureDetector(
                onTap: () => setState(() => _region = chips[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: sel ? c.primary : c.surfaceVariant, borderRadius: BorderRadius.circular(16)),
                  child: Text(
                    stickerRegionLabel(context, chips[i]),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? c.onPrimary : c.textSecondary),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: loading
              ? Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2.5))
              : failed
                  ? message(c, context.tr('Impossible de charger les packs.'), retry: true)
                  : items.isEmpty
                      ? message(c, context.tr('Aucun pack dans cette région pour le moment'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 6, bottom: 14),
                          itemCount: items.length,
                          itemBuilder: (_, i) => card(items[i]),
                        ),
        ),
      ],
    );
  }
}

/// Onglet « Créateurs » : mes packs achetés, accès au studio, puis packs de créateurs par ventes.
class StickerCreatorsTab extends StatefulWidget {
  final String userId;
  final bool canSend;
  final ValueChanged<StickerItem> onPick;

  const StickerCreatorsTab({super.key, required this.userId, required this.canSend, required this.onPick});

  @override
  State<StickerCreatorsTab> createState() => _StickerCreatorsTabState();
}

class _StickerCreatorsTabState extends _PackTabState<StickerCreatorsTab> {
  @override
  String get userId => widget.userId;
  @override
  bool get canSend => widget.canSend;
  @override
  ValueChanged<StickerItem> get onPick => widget.onPick;
  @override
  Future<List<StickerPack>> fetchPacks() => StickerService.instance.loadCreatorPacks();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    if (loading) return Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2.5));
    if (failed) return message(c, context.tr('Impossible de charger les packs.'), retry: true);

    Widget title(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Text(t, style: TextStyle(color: c.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w800)),
        );

    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                side: BorderSide(color: c.primary.withOpacity(0.6)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              icon: const Icon(Icons.brush_rounded, size: 18),
              label: Text(context.tr('Devenir créateur / Mon studio'), style: const TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StickerStudioPage()));
                if (mounted) load();
              },
            ),
          ),
        ),
        if (ownedPacks.isNotEmpty) ...[
          title(context.tr('Mes packs')),
          for (final p in ownedPacks) card(p),
        ],
        title(context.tr('Packs des créateurs')),
        if (packs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(context.tr('Aucun pack de créateur pour le moment'),
                  style: TextStyle(color: c.textSecondary, fontSize: 13)),
            ),
          )
        else
          for (final p in packs) card(p),
      ],
    );
  }
}
