import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/pseudo_tag.dart';

/// Zone de l'écran (224 × 454) où l'action est mise en lumière, pour les écrans « fidèles ».
class TutoSpot {
  final double top, left, right, height;
  const TutoSpot(this.top, this.left, this.right, this.height);
}

const _gold = Color(0xFFF5C542);
const _live = Color(0xFFF9A825); // or utilisé dans la vraie page de live
const _green = Color(0xFF2ECC71);

Color _goldOn(AppColors c) => c.isDark ? _gold : const Color(0xFF8A5A00);
Color _goldBg(AppColors c) => c.isDark ? const Color(0xFF2A2410) : const Color(0xFFFFF4D6);

Widget _avatar(double d, {Color? a, Color? b}) => Container(
      width: d,
      height: d,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [a ?? _green, b ?? _gold])),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Page de LIVE (reproduit livePage.dart) : hôte en haut à gauche, compteurs en haut à droite,
// messages et cadeaux à gauche, solde + cadeaux rapides + barre de message + actions en bas.
// Le live est toujours sur fond vidéo sombre, quel que soit le thème.
// ─────────────────────────────────────────────────────────────────────────────
Widget tutoLayoutLive(BuildContext ctx) {
  Widget chip(String t, {Color color = Colors.white70}) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
        child: Text(t, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
      );
  Widget msg(String who, String text, {bool gift = false}) => Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(8),
          border: gift ? const Border(left: BorderSide(color: _live, width: 2.5)) : null,
        ),
        child: Row(children: [
          _avatar(16),
          const SizedBox(width: 5),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              PseudoTag(label: who, style: TextStyle(color: gift ? _live : Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(ctx.tr(text),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: gift ? _live : Colors.white, fontSize: 9.5, fontWeight: gift ? FontWeight.w800 : FontWeight.w500)),
            ]),
          ),
        ]),
      );
  Widget quickGift(String icon, String price) => Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Text('$icon $price', style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700)),
      );
  Widget action(IconData i, Color col, String l) => Padding(
        padding: const EdgeInsets.only(left: 5),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, color: col, size: 15),
          Text(l, style: const TextStyle(color: Colors.white70, fontSize: 7.5)),
        ]),
      );

  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A1A2E), Color(0xFF0B0B0B)]),
    ),
    child: Stack(children: [
      const Center(child: Opacity(opacity: .22, child: Text('🎤', style: TextStyle(fontSize: 96)))),
      // Hôte
      Positioned(
        top: 12,
        left: 8,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _avatar(24),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const PseudoTag(label: '@nadia.vibes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 9)),
              Text(ctx.tr('12,4 k abonnés'), style: const TextStyle(color: Colors.white54, fontSize: 8)),
            ]),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: _live, borderRadius: BorderRadius.circular(9)),
              child: Text(ctx.tr('Suivre'), style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      ),
      // Compteurs
      Positioned(
        top: 12,
        right: 8,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFFD62B4A), borderRadius: BorderRadius.circular(10)),
            child: const Text('● LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
          ),
          chip('👥 128/340'),
          chip('❤️ 1,2 k', color: Colors.pinkAccent),
          chip('⭐ 3 400 pcs', color: _live),
        ]),
      ),
      // Messages et cadeaux reçus
      Positioned(
        left: 8,
        bottom: 96,
        width: 150,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          msg('@kofi.mensah', 'Magnifique 🔥'),
          msg('@awa.diallo', '🎁 Couronne +120 pcs', gift: true),
          msg('@moussa.sow', 'Bravo !'),
        ]),
      ),
      // Pied de page
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(.92), Colors.transparent])),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: _live.withOpacity(.15), borderRadius: BorderRadius.circular(11), border: Border.all(color: _live.withOpacity(.4))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('${ctx.tr('Dépôt')} 300', style: const TextStyle(color: _live, fontSize: 8, fontWeight: FontWeight.w700)),
                  Text('${ctx.tr('Gagnées')} 1 240', style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(width: 5),
              quickGift('🌹', '20'),
              quickGift('👑', '120'),
              quickGift('🦁', '500'),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)),
                  child: Row(children: [
                    Expanded(child: Text(ctx.tr('Envoyer un message...'), style: const TextStyle(color: Colors.white38, fontSize: 9.5))),
                    const Icon(Icons.send_rounded, color: _live, size: 14),
                  ]),
                ),
              ),
              action(Icons.favorite_rounded, Colors.pinkAccent, '1,2k'),
              action(Icons.stars_rounded, _live, ctx.tr('Cadeau')),
              action(Icons.people_rounded, Colors.white70, '128'),
            ]),
          ]),
        ),
      ),
    ]),
  );
}
const tutoSpotLiveGifts = TutoSpot(366, 4, 4, 30);

/// Live PRIVÉ : entrée payante affichée avant de rejoindre.
Widget tutoLayoutLivePrivate(BuildContext ctx) {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A1A2E), Color(0xFF0B0B0B)]),
    ),
    child: Stack(children: [
      const Center(child: Opacity(opacity: .12, child: Text('🎤', style: TextStyle(fontSize: 96)))),
      Positioned(
        top: 12,
        left: 8,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _avatar(24),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const PseudoTag(label: '@nadia.vibes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 9)),
              Text('🔒 ${ctx.tr('Live privé')}', style: const TextStyle(color: Colors.white54, fontSize: 8)),
            ]),
          ]),
        ),
      ),
      Positioned(
        left: 16,
        right: 16,
        top: 120,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF17151A), borderRadius: BorderRadius.circular(16), border: Border.all(color: _live.withOpacity(.5))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔒', style: TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(ctx.tr('Live privé'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(ctx.tr('Payez 100 pièces pour regarder'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
            const SizedBox(height: 10),
            Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _live, borderRadius: BorderRadius.circular(11)),
              child: Text(ctx.tr('Payer 100 pièces'), style: const TextStyle(color: Colors.black, fontSize: 11.5, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 8),
            Text(ctx.tr('Quitter le live'), style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
          ]),
        ),
      ),
    ]),
  );
}
const tutoSpotLivePay = TutoSpot(213, 22, 22, 34);

// ─────────────────────────────────────────────────────────────────────────────
// Page COMMENTAIRES (reproduit postComments.dart) : en-tête du post, bandeau des pièces
// rapportées, liste de commentaires (❤ / Répondre, réponses en retrait), barre de saisie.
// ─────────────────────────────────────────────────────────────────────────────
Widget tutoLayoutComments(BuildContext ctx, AppColors c) {
  final gold = _goldOn(c);
  Widget comment(String who, String time, String text, {String likes = '', bool gift = false, bool reply = false}) => Padding(
        padding: EdgeInsets.fromLTRB(reply ? 34 : 12, 0, 10, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _avatar(reply ? 18 : 24),
          const SizedBox(width: 7),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                PseudoTag(label: who, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 9.5)),
                const SizedBox(width: 5),
                Text(time, style: TextStyle(color: c.textSecondary, fontSize: 8.5)),
                if (gift) ...[
                  const SizedBox(width: 5),
                  Text('🎁 ${ctx.tr('cadeau')}', style: TextStyle(color: gold, fontSize: 8.5, fontWeight: FontWeight.w800)),
                ],
              ]),
              Text(ctx.tr(text), style: TextStyle(color: c.textPrimary, fontSize: 10.5)),
              if (!reply)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(children: [
                    Icon(Icons.favorite_border_rounded, size: 12, color: c.textSecondary),
                    const SizedBox(width: 3),
                    Text(likes, style: TextStyle(color: c.textSecondary, fontSize: 9)),
                    const SizedBox(width: 12),
                    Icon(Icons.mode_comment_outlined, size: 12, color: c.textSecondary),
                    const SizedBox(width: 3),
                    Text(ctx.tr('Répondre'), style: TextStyle(color: c.textSecondary, fontSize: 9)),
                  ]),
                ),
            ]),
          ),
        ]),
      );

  return Column(children: [
    // En-tête du post
    Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
      child: Row(children: [
        _avatar(26),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PseudoTag(label: '@nadia.vibes', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 10)),
            Text(ctx.tr('Ma routine selfie du matin ☀️'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 9.5)),
          ]),
        ),
      ]),
    ),
    // Bandeau « Ce post a rapporté … » (même bandeau que sur les pages de détails)
    Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: _goldBg(c), borderRadius: BorderRadius.circular(9), border: Border.all(color: gold.withOpacity(.55))),
      child: Row(children: [
        const Text('🪙', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(ctx.tr('Ce post a rapporté 42 pièces à @nadia.vibes'),
              maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: gold, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
        Icon(Icons.chevron_right_rounded, size: 15, color: gold),
      ]),
    ),
    comment('@kofi.mensah', '2 h', 'Superbe photo 🔥', likes: '12'),
    comment('@nadia.vibes', '1 h', 'Merci beaucoup ! 🙏', reply: true),
    comment('@awa.diallo', '1 h', 'J’adore ce look !', likes: '5', gift: true),
    comment('@moussa.sow', '30 min', 'Trop stylé', likes: '2'),
    const Spacer(),
    // Barre de saisie
    Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: Row(children: [
        Icon(Icons.emoji_emotions_outlined, size: 20, color: c.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(16)),
            child: Text(ctx.tr('Ajouter un commentaire...'), style: TextStyle(color: c.textSecondary, fontSize: 10)),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 15),
        ),
      ]),
    ),
  ]);
}
const tutoSpotCommentInput = TutoSpot(410, 4, 4, 44);

// ─────────────────────────────────────────────────────────────────────────────
// Page de DÉTAILS d'un post (image) : en-tête, média, bandeau des pièces, rangée de stats.
// ─────────────────────────────────────────────────────────────────────────────
Widget tutoLayoutPost(BuildContext ctx, AppColors c) {
  final gold = _goldOn(c);
  Widget stat(String t) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(12)),
        child: Text(t, style: TextStyle(color: c.textPrimary, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          _avatar(32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              PseudoTag(label: '@nadia.vibes', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 10.5)),
              Text(ctx.tr('12,4 k abonnés'), style: TextStyle(color: c.textSecondary, fontSize: 9.5)),
            ]),
          ),
        ]),
      ),
    ),
    Container(
      height: 150,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1E5D3A), Color(0xFF8A6D18)])),
      alignment: Alignment.center,
      child: const Text('📸', style: TextStyle(fontSize: 44)),
    ),
    Container(
      height: 34,
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: _goldBg(c), borderRadius: BorderRadius.circular(9), border: Border.all(color: gold.withOpacity(.55))),
      child: Row(children: [
        const Text('🪙', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(ctx.tr('Ce post a rapporté 3 200 pièces à @nadia.vibes'),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: gold, fontSize: 9.5, fontWeight: FontWeight.w700)),
        ),
        Icon(Icons.chevron_right_rounded, size: 15, color: gold),
      ]),
    ),
    Container(
      height: 30,
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Row(children: [stat('❤️ 3 200'), stat('💬 42'), stat('🎁 18'), stat('👁 48 k')]),
    ),
  ]);
}
const tutoSpotPostLikes = TutoSpot(292, 4, 96, 36);
const tutoSpotPostGifts = TutoSpot(292, 118, 30, 36);
