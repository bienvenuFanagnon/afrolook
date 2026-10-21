import 'dart:io';
import 'package:afrotok/ads/rewarded_ads.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../ads/admob_service.dart';
import '../../ads/rewards_service.dart';
import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../services/template_link.dart';
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
  CardResult({required this.image, required this.caption, required this.pro, required this.format, this.sourcePostId, this.voteLink, this.templateRef});

  /// Style (et modèle) de la carte, pour « Essayer ce modèle » sous le post publié (voir template_link.dart).
  final String? templateRef;
  final Uint8List image;

  /// Post d'origine de la carte (carte créée depuis un post existant) : la publication crée un NOUVEAU post, l'ancien n'est pas modifié.
  final String? sourcePostId;

  /// Lien « Vote pour moi » de la carte (participation à un DÉFI) : le post est publié avec l'identifiant qu'il contient.
  final String? voteLink;
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

  /// Légende d'une participation à un DÉFI : la mention de vote et le lien du post, pour qu'on puisse voter depuis un autre réseau.
  static String voteCaption(String mention, String link) => '🏆 $mention ! ${tr('Je participe au défi sur Afrolook')}\n👉 $link\n#defiafrolook #carteafrolook';

  /// Partage de la carte (JPEG) avec un texte : la carte publiée dans Afrolook se partage ensuite sur les autres réseaux.
  static Future<void> shareCard(Uint8List jpeg, {String? text}) async {
    final f = await File('${Directory.systemTemp.path}/carte_vote_${DateTime.now().millisecondsSinceEpoch}.jpg').writeAsBytes(jpeg, flush: true);
    await Share.shareXFiles([XFile(f.path, mimeType: 'image/jpeg')], text: text);
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
    final earned = await RewardedAds.watch(userId: user.id);
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
  static Future<bool> publishAsPost(BuildContext context, CardResult r, CardQuote quote, {Canal? canal, String? defiPostId, bool asDefi = false, String? presetPostId}) async {
    PostTemplateLink.set(r.templateRef);
    final bool? done;
    try {
      done = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => _PostPublishPage(result: r, quote: quote, canal: canal, defiPostId: defiPostId, asDefi: asDefi, presetPostId: presetPostId)),
      );
    } finally {
      PostTemplateLink.set(null); // une carte non publiée ne doit pas marquer le prochain post
    }
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
    final dir = await getTemporaryDirectory();
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
  const _PostPublishPage({required this.result, required this.quote, this.canal, this.defiPostId, this.asDefi = false, this.presetPostId});
  final bool asDefi;
  final String? presetPostId;
  final CardResult result;
  final CardQuote quote;
  final Canal? canal;
  final String? defiPostId;

  Future<void> _offerShare(BuildContext context) async {
    final c = AppColors.of(context);
    final link = result.voteLink!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ctx.tr('Ta participation est publiée 🏆'), style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(ctx.tr('Partage ta carte sur WhatsApp, Facebook, TikTok… Tes amis scannent le QR code ou ouvrent le lien pour voter pour toi dans Afrolook.'), style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.4)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await CardFlow.shareCard(result.image, text: CardFlow.voteCaption(ctx.tr('Vote pour moi'), link));
                },
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(ctx.tr('Partager ma carte')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(ctx.tr('Lien copié'))));
                },
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text(ctx.tr('Copier le lien de mon post')),
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Center(child: Text(ctx.tr('Plus tard')))),
          ]),
        ),
      ),
    );
  }

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
        presetPostId: presetPostId,
        initialImages: [result.image],
        initialDescription: result.caption,
        initialPostType: asDefi && defiPostId == null ? 'DEFI' : null,
        beforePublish: () => CardFlow.commit(context, CardKind.publish, pro: result.pro, quote: quote),
        onPublished: () async {
          // participation à un DÉFI avec une carte « Vote pour moi » : on propose tout de suite de la partager pour récolter des votes
          if (result.voteLink != null && context.mounted) await _offerShare(context);
          if (context.mounted) Navigator.of(context).pop(true);
        },
      )),
      ]),
    );
  }
}
