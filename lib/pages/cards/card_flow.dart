import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';

import '../../ads/admob_service.dart';
import '../../ads/rewards_service.dart';
import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../chronique/chroniqueform.dart';
import '../coins/coin_recharge_screen.dart';
import '../userPosts/postTabs/userPostImageTab.dart';
import 'card_models.dart';
import 'card_service.dart';
import 'card_text.dart';

/// Carte prête à être publiée ou utilisée : l'image (JPEG 1080 px), la légende proposée et le style choisi.
class CardResult {
  CardResult({required this.image, required this.caption, required this.pro, required this.format, this.sourcePostId});
  final Uint8List image;

  /// Post d'origine de la carte (carte créée depuis un post existant) : la publication crée un NOUVEAU post, l'ancien n'est pas modifié.
  final String? sourcePostId;
  final String caption;

  /// Un style Pro a été choisi (coût supplémentaire, sauf avec le pass).
  final bool pro;
  final CardFormat format;
}

/// Étapes communes du Studio : paiement d'une carte, légendes, publication (post ou Chronique) avec les MÊMES règles
/// que les posts et les chroniques ordinaires.
class CardFlow {
  CardFlow._();

  /// Convertit l'image PNG de la carte en JPEG (publication). Hors appareil (tests), garde le PNG.
  static Future<Uint8List> toJpeg(Uint8List png, {int quality = 90}) async {
    try {
      return await FlutterImageCompress.compressWithList(png, minWidth: 1080, minHeight: 1080, quality: quality, format: CompressFormat.jpeg);
    } catch (_) {
      return png;
    }
  }

  /// Légende proposée pour un post : respecte les règles du post image (au moins 10 caractères et un hashtag).
  static String postCaption(CardSource s) {
    // Carte créée depuis un post qui a déjà une description : on la reprend telle quelle (modifiable avant de publier).
    final original = s.text.trim();
    if (s.postId != null && original.isNotEmpty && (s.externalLink ?? '').isEmpty) {
      final credit = s.credit == null ? '' : '\n\nPost de @${s.pseudo}';
      final tag = original.toLowerCase().contains('#carteafrolook') ? '' : '\n#carteafrolook';
      return '$original$credit$tag';
    }
    final body = separateTags(s.text).body;
    final excerpt = body.isEmpty ? '' : ' — ${cutText(body, 110).text}';
    // carte « lien » : la légende reprend l'adresse de la vidéo
    if ((s.externalLink ?? '').isNotEmpty) return '✨ Carte Afrolook$excerpt\n🔗 ${s.externalLink}\n#carteafrolook';
    final credit = s.credit == null ? '' : '\nPost de @${s.pseudo}';
    return '✨ Carte Afrolook$excerpt$credit\n#carteafrolook';
  }

  /// Légende proposée pour une chronique (100 caractères au plus).
  static String chroniqueCaption(CardSource s) => 'Carte Afrolook · @${s.pseudo}'.characters.take(100).toString();

  /// Débite (ou enregistre) une carte avant de la sortir. Demande confirmation si des pièces sont débitées, propose de
  /// recharger ou de regarder une pub si le solde ne suffit pas. Retourne true si la carte peut sortir.
  static Future<bool> commit(BuildContext context, CardKind kind, {required bool pro, required CardQuote quote}) async {
    final cost = quote.cost(kind, pro: pro);
    if (cost.coins > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final c = AppColors.of(ctx);
          return AlertDialog(
            backgroundColor: c.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(ctx.tr('Payer {n} 🪙 ?', {'n': cost.coins}), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
            content: Text(
              kind == CardKind.capture
                  ? ctx.tr('Enregistrer ou partager cette carte coûte {n} pièces. Ton solde : {b} 🪙.', {'n': cost.coins, 'b': quote.balance})
                  : ctx.tr('Publier cette carte coûte {n} pièces. Ton solde : {b} 🪙.', {'n': cost.coins, 'b': quote.balance}),
              style: TextStyle(color: c.textSecondary, height: 1.4),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Annuler'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Payer'))),
            ],
          );
        },
      );
      if (ok != true) return false;
    }
    if (!context.mounted) return false;
    if (kind == CardKind.capture && quote.plan == 'free' && cost.via == 'quota' && !await _freeCardAd(context)) return false;
    if (!context.mounted) return false;
    return _send(context, kind, pro: pro, quote: quote);
  }

  /// La carte offerte du mois d'un compte gratuit se « paie » avec une pub récompensée. Si aucune pub n'est
  /// disponible (désactivées, pas de remplissage, hors connexion), la carte reste offerte : on ne bloque jamais le partage.
  static Future<bool> _freeCardAd(BuildContext context) async {
    final user = context.read<UserAuthProvider>().loginUserData;
    if (!RewardsService.available(user)) return true;
    AdmobService.loadRewarded();
    for (var i = 0; i < 8 && !AdmobService.rewardedReadyNotifier.value; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (!AdmobService.rewardedReadyNotifier.value || !context.mounted) return true;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(ctx.tr('Ta carte offerte du mois'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          content: Text(ctx.tr('Regarde une courte pub pour enregistrer ou partager cette carte gratuitement.'), style: TextStyle(color: c.textSecondary, height: 1.4)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Annuler'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Regarder la pub'))),
          ],
        );
      },
    );
    if (go != true) return false;
    final earned = await AdmobService.watchRewarded(userId: user.id);
    if (!earned && context.mounted) _say(context, tr('Regarde la pub jusqu\'au bout pour obtenir ta carte offerte.'));
    return earned;
  }

  static Future<bool> _send(BuildContext context, CardKind kind, {required bool pro, required CardQuote quote, bool retried = false}) async {
    try {
      await CardService.commit(kind, pro: pro);
      if (context.mounted) {
        // met à jour le solde affiché dans l'application
        context.read<UserAuthProvider>().refreshUserData();
      }
      return true;
    } on CardInsufficient catch (e) {
      if (!context.mounted) return false;
      final again = await _offerTopUp(context, kind, e, retried);
      if (again && context.mounted) {
        final fresh = await CardService.quote();
        if (!context.mounted) return false;
        return _send(context, kind, pro: pro, quote: fresh, retried: true);
      }
      return false;
    } on CardsDisabled {
      if (context.mounted) _say(context, tr('Le Studio Cartes est momentanément indisponible.'));
      return false;
    } catch (_) {
      if (context.mounted) _say(context, tr('Impossible de valider la carte pour le moment. Réessaie dans un instant.'));
      return false;
    }
  }

  static void _say(BuildContext context, String t) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t)));
  }

  /// Solde insuffisant : regarder une pub (capture seulement), recharger ses pièces, ou renoncer.
  /// Retourne true si l'utilisateur a obtenu de quoi réessayer.
  static Future<bool> _offerTopUp(BuildContext context, CardKind kind, CardInsufficient e, bool retried) async {
    final user = context.read<UserAuthProvider>().loginUserData;
    final canAd = kind == CardKind.capture && RewardsService.available(user);
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(ctx.tr('Il te faut {n} 🪙', {'n': e.coins}), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          content: Text(
            ctx.tr('Ton solde est de {b} 🪙. Recharge tes pièces pour continuer.', {'b': e.balance}) +
                (canAd ? '\n\n${ctx.tr('Ou regarde une pub : elle t\'offre une capture sans pièces.')}' : ''),
            style: TextStyle(color: c.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('Annuler'))),
            if (canAd) TextButton(onPressed: () => Navigator.pop(ctx, 'ad'), child: Text(ctx.tr('Regarder une pub'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'buy'), child: Text(ctx.tr('Recharger'))),
          ],
        );
      },
    );
    if (choice == null || !context.mounted) return false;
    if (choice == 'ad') {
      try {
        final ok = await RewardsService.watchAndClaim('card_capture', user.id ?? '');
        if (!context.mounted) return false;
        if (!ok) _say(context, tr('Aucune vidéo disponible pour le moment, réessaie dans un instant.'));
        return ok;
      } catch (_) {
        if (context.mounted) _say(context, tr('Impossible d\'obtenir la récompense pour le moment.'));
        return false;
      }
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
    return true; // on réessaie : le serveur dira si le solde suffit maintenant
  }

  /// Publication en post : l'écran « image » des posts, déjà rempli avec la carte. Mêmes règles qu'un post
  /// (images max, caractères, délai entre deux posts, pays…), le débit de la carte se fait à la vraie publication.
  /// [asDefi] : « Lancer un défi avec cette carte » : même écran, avec le type « Défi » déjà choisi (cagnotte, date de fin…).
  static Future<bool> publishAsPost(BuildContext context, CardResult r, CardQuote quote, {Canal? canal, String? defiPostId, bool asDefi = false}) async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _PostPublishPage(result: r, quote: quote, canal: canal, defiPostId: defiPostId, asDefi: asDefi)),
    );
    return done == true;
  }

  /// Après la création d'une carte (création depuis la page de publication) : publier simplement ou lancer un défi avec elle.
  /// Retourne 'post', 'defi', ou null si l'utilisateur renonce.
  static Future<String?> askPostOrDefi(BuildContext context) {
    final c = AppColors.of(context);
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(ctx.tr('Ta carte est prête'), style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ListTile(
              leading: Icon(Icons.article_outlined, color: c.primary),
              title: Text(ctx.tr('Publier en post'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
              subtitle: Text(ctx.tr('Sur ton profil, avec légende'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'post'),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_rounded, color: Color(0xFFFF9500)),
              title: Text(ctx.tr('Lancer un défi avec cette carte'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
              subtitle: Text(ctx.tr('Les autres participent, la communauté vote'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
              onTap: () => Navigator.pop(ctx, 'defi'),
            ),
          ]),
        ),
      ),
    );
  }

  /// Publication en Chronique : le formulaire des chroniques, déjà rempli avec la carte (même règles qu'une chronique image).
  static Future<bool> publishAsChronique(BuildContext context, CardResult r, CardQuote quote, {String? caption}) async {
    final dir = Directory.systemTemp;
    final file = await File('${dir.path}/carte_chronique_${DateTime.now().millisecondsSinceEpoch}.jpg').writeAsBytes(r.image, flush: true);
    if (!context.mounted) return false;
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => AddChroniquePage(
          initialImage: file,
          initialText: caption ?? '',
          beforePublish: () => commit(ctx, CardKind.publish, pro: r.pro, quote: quote),
        ),
      ),
    );
    return done == true;
  }
}

class _PostPublishPage extends StatelessWidget {
  const _PostPublishPage({required this.result, required this.quote, this.canal, this.defiPostId, this.asDefi = false});
  final bool asDefi;
  final CardResult result;
  final CardQuote quote;
  final Canal? canal;
  final String? defiPostId;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: Text(asDefi ? context.tr('Lancer un défi avec la carte') : context.tr('Publier la carte'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(children: [
        if (result.sourcePostId != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 18, color: c.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('Ceci crée un nouveau post : la carte devient son image. Le post d’origine n’est pas modifié. Tu peux changer la description avant de publier.'),
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.4),
                ),
              ),
            ]),
          ),
        Expanded(child: UserPostLookImageTab(
        canal: canal,
        defiPostId: defiPostId,
        initialImages: [result.image],
        initialDescription: result.caption,
        initialPostType: asDefi && defiPostId == null ? 'DEFI' : null,
        beforePublish: () => CardFlow.commit(context, CardKind.publish, pro: result.pro, quote: quote),
        onPublished: () => Navigator.of(context).pop(true),
      )),
      ]),
    );
  }
}
