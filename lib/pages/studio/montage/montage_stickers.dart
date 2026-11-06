import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';
import '../../../theme/app_colors.dart';

/// Un autocollant posé sur la photo ou la vidéo du montage : un emoji, une pastille de texte (« NOUVEAU », « PROMO »…) ou le logo Afrolook.
/// Sa position est le CENTRE, en fraction du cadre (0 à 1) ; l'affichage la ramène toujours à l'intérieur du cadre : un autocollant ne se perd jamais hors de l'écran.
class MontageSticker {
  MontageSticker({required this.id, required this.kind, required this.value, this.center = const Offset(.5, .45), this.scale = 1});

  /// Identifiant unique dans le montage.
  final String id;

  /// `emoji`, `badge` ou `logo`.
  final String kind;

  /// Le caractère emoji, le texte de la pastille, ou `afrolook` pour le logo.
  final String value;

  /// Centre dans le cadre (fraction de la largeur et de la hauteur).
  Offset center;

  /// Taille relative (1 = taille normale), entre [kStickerMinScale] et [kStickerMaxScale].
  double scale;
}

const double kStickerMinScale = .5;
const double kStickerMaxScale = 4;

/// Nombre maximal d'autocollants sur un même montage (garde l'image légère et lisible).
const int kMaxStickers = 12;

/// Une page du pack : un titre et ses éléments.
class StickerCategory {
  const StickerCategory(this.id, this.title, this.icon, this.items, {this.kind = 'emoji'});
  final String id;
  final String title;
  final IconData icon;
  final List<String> items;
  final String kind;
}

/// Pack prêt à choisir (emojis du téléphone, donc lisibles partout ; pastilles et logo propres à Afrolook).
const List<StickerCategory> kStickerPack = [
  StickerCategory('faces', 'Visages', Icons.emoji_emotions_rounded, ['😀', '😁', '😂', '🤣', '😍', '🥰', '😎', '🤩', '🥳', '😭', '😡', '🤗', '😜', '🤔', '😱', '😴']),
  StickerCategory('love', 'Cœurs', Icons.favorite_rounded, ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '💖', '💘', '💕', '😘', '🔥', '✨', '💯', '💥']),
  StickerCategory('party', 'Fête', Icons.celebration_rounded, ['🎉', '🎊', '🎈', '🎁', '🥂', '🍾', '🎂', '🪩', '🌟', '⭐', '🎆', '🎇', '🕺', '💃', '🎶', '🎵']),
  StickerCategory('africa', 'Afrique', Icons.public_rounded, ['🌍', '🥁', '🪘', '🌴', '🦁', '🐘', '🦓', '🥭', '☀️', '🌅', '🇹🇬', '🇬🇭', '🇳🇬', '🇸🇳', '🇨🇮', '🇧🇯', '🇨🇲', '🇲🇱']),
  StickerCategory('sport', 'Sport', Icons.sports_soccer_rounded, ['⚽', '🏀', '🏆', '🥇', '🥈', '🥉', '💪', '🏃', '🥊', '🎽', '🏅', '🎯', '🚴', '🏋️']),
  StickerCategory('hands', 'Gestes', Icons.waving_hand_rounded, ['👍', '👏', '🙌', '🙏', '✌️', '👊', '🤝', '👌', '🤞', '👋', '💪', '🫶']),
  StickerCategory('things', 'Objets', Icons.diamond_rounded, ['📸', '🎤', '🎧', '💎', '👑', '🕶️', '💸', '💰', '🪙', '🛍️', '🚗', '✈️', '📱', '💡', '🎬', '📣']),
  StickerCategory('badges', 'Pastilles', Icons.label_rounded, ['NOUVEAU', 'PROMO', '-50 %', 'LIVE', 'MERCI', 'BRAVO', 'À VENDRE', 'GRATUIT', 'EN DIRECT', 'BONNE ANNÉE'], kind: 'badge'),
  StickerCategory('app', 'Afrolook', Icons.auto_awesome_rounded, ['afrolook'], kind: 'logo'),
];

/// Couleurs des pastilles de texte (fond), choisies pour rester lisibles avec un texte blanc ou sombre.
const List<(Color bg, Color fg)> kBadgeColors = [
  (Color(0xFFFFC400), Color(0xFF1A1500)),
  (Color(0xFFE5484D), Color(0xFFFFFFFF)),
  (Color(0xFF1F8A4C), Color(0xFFFFFFFF)),
  (Color(0xFF244B8F), Color(0xFFFFFFFF)),
  (Color(0xFF111111), Color(0xFFFFFFFF)),
];

/// Pastille de texte, dans sa couleur d'après le texte (toujours la même pour un même texte).
(Color bg, Color fg) badgeColorsFor(String text) => kBadgeColors[text.codeUnits.fold<int>(0, (a, b) => a + b) % kBadgeColors.length];

/// Dessin d'un autocollant à la taille [cq] (1 % de la largeur du cadre) : le même pour l'aperçu et pour l'export.
class StickerView extends StatelessWidget {
  const StickerView({super.key, required this.sticker, required this.cq, this.selected = false});

  final MontageSticker sticker;
  final double cq;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final base = 14 * cq * sticker.scale.clamp(kStickerMinScale, kStickerMaxScale);
    Widget body;
    switch (sticker.kind) {
      case 'badge':
        final (bg, fg) = badgeColorsFor(sticker.value);
        body = Container(
          padding: EdgeInsets.symmetric(horizontal: base * .3, vertical: base * .14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(base * .22), border: Border.all(color: Colors.white, width: base * .05), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 4)]),
          child: Text(sticker.value, maxLines: 1, style: TextStyle(fontFamily: 'NunitoBold', fontSize: base * .4, color: fg, height: 1.1)),
        );
      case 'logo':
        body = Container(
          padding: EdgeInsets.all(base * .08),
          decoration: BoxDecoration(color: const Color(0x66000000), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: base * .04)),
          child: Image.asset('assets/logo/afrolook_logo.png', width: base * .8, height: base * .8),
        );
      default:
        body = Text(sticker.value, style: TextStyle(fontSize: base, height: 1.05, shadows: const [Shadow(color: Color(0x44000000), blurRadius: 3)]));
    }
    if (!selected) return body;
    // sélectionné : cadre en pointillés légers (repère pour l'édition, jamais exporté : l'export se fait sans sélection)
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: .5 * cq), borderRadius: BorderRadius.circular(1.2 * cq)),
      child: Padding(padding: EdgeInsets.all(.8 * cq), child: body),
    );
  }
}

/// Feuille du pack : des onglets par thème, une grille ; toucher un élément le choisit. Rend le choix `(kind, value)` ou null.
Future<({String kind, String value})?> showStickerPicker(BuildContext context) {
  final c = AppColors.of(context);
  return showModalBottomSheet<({String kind, String value})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => const _PickerSheet(),
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet();

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final cat = kStickerPack[_tab];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .6,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(99))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Align(alignment: Alignment.centerLeft, child: Text(context.tr('Ajouter un autocollant'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800))),
          ),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kStickerPack.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final on = i == _tab;
                return GestureDetector(
                  key: ValueKey('sticker_tab_${kStickerPack[i].id}'),
                  onTap: () => setState(() => _tab = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: on ? c.accent : c.surfaceVariant, borderRadius: BorderRadius.circular(99), border: Border.all(color: on ? c.accent : c.border)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(kStickerPack[i].icon, size: 17, color: on ? c.onAccent : c.textSecondary),
                      const SizedBox(width: 6),
                      Text(context.tr(kStickerPack[i].title), style: TextStyle(color: on ? c.onAccent : c.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: cat.kind == 'badge' ? 130 : 64, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: cat.kind == 'badge' ? 2.2 : 1),
              itemCount: cat.items.length,
              itemBuilder: (_, i) {
                final v = cat.items[i];
                return GestureDetector(
                  key: ValueKey('sticker_${cat.id}_$i'),
                  onTap: () => Navigator.pop(context, (kind: cat.kind, value: v)),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
                    child: cat.kind == 'emoji'
                        ? Text(v, style: const TextStyle(fontSize: 30))
                        : StickerView(sticker: MontageSticker(id: 'preview', kind: cat.kind, value: v), cq: 2.6),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
