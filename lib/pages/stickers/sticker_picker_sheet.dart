import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/stickers/sticker_models.dart';
import '../../services/stickers/sticker_service.dart';
import '../../theme/app_colors.dart';
import 'sticker_widgets.dart';

/// Ouvre le sélecteur ; renvoie le sticker touché (ou null si fermé).
/// L'envoi lui-même est fait par l'appelant.
Future<StickerItem?> showStickerPicker(
  BuildContext context, {
  required String userId,
  String? postId,
  StickerAccess? initialAccess,
  List<StickerItem> initialRecents = const [],
}) {
  final h = MediaQuery.of(context).size.height;
  return showModalBottomSheet<StickerItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: BoxConstraints(maxHeight: h * 0.78),
    builder: (_) => StickerPickerSheet(
      userId: userId,
      postId: postId,
      initialAccess: initialAccess,
      initialRecents: initialRecents,
    ),
  );
}

const List<String> _categoryOrder = [
  'joie', 'reussite', 'compliments', 'amour', 'surprise', 'taquinerie', 'soutien',
  'colere', 'reponses', 'contenus', 'fetes', 'sport', 'musique', 'afrolook', 'humeur',
];

String _categoryLabel(BuildContext context, String cat) {
  switch (cat) {
    case 'joie': return context.tr('Joie');
    case 'reussite': return context.tr('Réussite');
    case 'compliments': return context.tr('Compliments');
    case 'amour': return context.tr('Amour');
    case 'surprise': return context.tr('Surprise');
    case 'taquinerie': return context.tr('Taquinerie');
    case 'soutien': return context.tr('Soutien');
    case 'colere': return context.tr('Colère');
    case 'reponses': return context.tr('Réponses');
    case 'contenus': return context.tr('Contenus');
    case 'fetes': return context.tr('Fêtes');
    case 'sport': return context.tr('Sport');
    case 'musique': return context.tr('Musique');
    case 'afrolook': return context.tr('Afrolook');
    case 'humeur': return context.tr('Humeur');
    default: return cat.isEmpty ? context.tr('Autres') : cat[0].toUpperCase() + cat.substring(1);
  }
}

class StickerPickerSheet extends StatefulWidget {
  final String userId;
  final String? postId;
  final StickerAccess? initialAccess;
  final List<StickerItem> initialRecents;

  const StickerPickerSheet({
    super.key,
    required this.userId,
    this.postId,
    this.initialAccess,
    this.initialRecents = const [],
  });

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet> with SingleTickerProviderStateMixin {
  final StickerService _service = StickerService.instance;
  late final TabController _tabs = TabController(length: 5, vsync: this);
  final TextEditingController _searchCtrl = TextEditingController();

  List<StickerItem> _all = [];
  List<StickerItem> _recents = [];
  StickerAccess? _access;
  bool _loading = true;
  bool _failed = false;
  String _query = '';
  String _category = '_all'; // '_all', '_recents' ou une catégorie

  @override
  void initState() {
    super.initState();
    _access = widget.initialAccess;
    _recents = widget.initialRecents;
    if (_recents.isNotEmpty) _category = '_recents';
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    // Le mode dégradé (callable en échec) laisse le sélecteur s'ouvrir sans quotas.
    final accessF = _service.fetchAccess(postId: widget.postId);
    final recentsF = _service.loadRecents(widget.userId);
    try {
      final all = await _service.loadOfficialStickers();
      if (!mounted) return;
      setState(() {
        _all = all;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
    final access = await accessF;
    final recents = await recentsF;
    if (!mounted) return;
    setState(() {
      _access = access ?? _access;
      _recents = recents;
      if (recents.isEmpty && _category == '_recents') _category = '_all';
    });
  }

  List<String> get _categories {
    final present = _all.map((s) => s.category).toSet();
    return [
      ..._categoryOrder.where(present.contains),
      ...present.where((c) => !_categoryOrder.contains(c) && c.isNotEmpty),
    ];
  }

  List<StickerItem> get _visible {
    if (_query.trim().isNotEmpty) return _service.search(_all, _query);
    if (_category == '_recents') return _recents;
    if (_category == '_all') return _all;
    return _all.where((s) => s.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final blockedReason = (_access != null && !_access!.canSend) ? (_access!.reason ?? 'not_subscribed') : null;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 38, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: c.primary,
            unselectedLabelColor: c.textSecondary,
            indicatorColor: c.primary,
            dividerColor: c.divider.withOpacity(0.4),
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: context.tr('Afrolook'), height: 36),
              Tab(text: context.tr('Monde'), height: 36),
              Tab(text: context.tr('Créateurs'), height: 36),
              Tab(text: context.tr('Mes stickers'), height: 36),
              Tab(text: context.tr('Cadeaux'), height: 36),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildOfficialTab(c, blockedReason),
                _comingSoon(c, Icons.public_rounded),
                _comingSoon(c, Icons.brush_rounded),
                _comingSoon(c, Icons.add_reaction_outlined),
                _comingSoon(c, Icons.card_giftcard_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _comingSoon(AppColors c, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: c.textSecondary.withOpacity(0.6)),
            const SizedBox(height: 10),
            Text(context.tr('Bientôt disponible'),
                style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(context.tr('Cette section arrive prochainement.'),
                textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialTab(AppColors c, String? blockedReason) {
    final lang = Localizations.localeOf(context).languageCode;
    final items = _visible;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Container(
            height: 38,
            decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(20)),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: c.textPrimary, fontSize: 13.5),
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: context.tr('Rechercher un sticker'),
                hintStyle: TextStyle(color: c.textSecondary, fontSize: 13.5),
                prefixIcon: Icon(Icons.search_rounded, size: 19, color: c.textSecondary),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded, size: 17, color: c.textSecondary),
                        onPressed: () => setState(() {
                          _query = '';
                          _searchCtrl.clear();
                        }),
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
        ),
        _buildLimitsBanner(c, blockedReason),
        if (_query.trim().isEmpty) _buildCategoryChips(c),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2.5))
              : _failed
                  ? _message(c, context.tr('Impossible de charger les stickers.'), retry: true)
                  : items.isEmpty
                      ? _message(c, _query.trim().isNotEmpty
                          ? context.tr('Aucun sticker trouvé')
                          : (_all.isEmpty ? context.tr('Aucun sticker pour le moment') : context.tr('Aucun sticker dans cette catégorie')))
                      : Opacity(
                          opacity: blockedReason != null ? 0.4 : 1,
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
                            // Peu de cellules hors écran : l'animation ne se charge que pour ce qui est visible.
                            cacheExtent: 60,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.82,
                            ),
                            itemCount: items.length,
                            itemBuilder: (_, i) => _StickerCell(
                              sticker: items[i],
                              caption: _service.captionFor(items[i], lang),
                              enabled: blockedReason == null,
                              onTap: () => Navigator.pop(context, items[i]),
                            ),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _message(AppColors c, String text, {bool retry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(color: c.textSecondary, fontSize: 13)),
          if (retry)
            TextButton(onPressed: _load, child: Text(context.tr('Réessayer'), style: TextStyle(color: c.primary))),
        ],
      ),
    );
  }

  Widget _buildLimitsBanner(AppColors c, String? blockedReason) {
    final a = _access;
    if (a == null && blockedReason == null) return const SizedBox.shrink();
    final text = blockedReason != null
        ? stickerReasonText(context, blockedReason)
        : (a!.hasLimits
            ? context.tr('Sur ce post {a}/{b} · Aujourd\'hui {c}/{d}', {
                'a': a.postUsed, 'b': a.perPostMax, 'c': a.dayUsed, 'd': a.perDayMax,
              })
            : null);
    if (text == null) return const SizedBox.shrink();
    final color = blockedReason != null ? c.danger : c.textSecondary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(blockedReason != null ? Icons.info_outline_rounded : Icons.timelapse_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(AppColors c) {
    final chips = <MapEntry<String, String>>[
      if (_recents.isNotEmpty) MapEntry('_recents', context.tr('Récents')),
      MapEntry('_all', context.tr('Tous')),
      for (final cat in _categories) MapEntry(cat, _categoryLabel(context, cat)),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final sel = chips[i].key == _category;
          return GestureDetector(
            onTap: () => setState(() => _category = chips[i].key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? c.primary : c.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                chips[i].value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? c.onPrimary : c.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Cellule de grille : miniature tout de suite, animation dès que la cellule est construite (visible).
class _StickerCell extends StatelessWidget {
  final StickerItem sticker;
  final String? caption;
  final bool enabled;
  final VoidCallback onTap;

  const _StickerCell({required this.sticker, required this.caption, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(color: c.surfaceVariant.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 3),
        child: Column(
          children: [
            Expanded(child: Center(child: StickerImage(sticker: sticker, loadAnimation: enabled))),
            if (caption != null)
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 9.5, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }
}
