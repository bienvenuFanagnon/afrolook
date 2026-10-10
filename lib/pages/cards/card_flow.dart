import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:provider/provider.dart';

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
  CardResult({required this.image, required this.caption, required this.pro, required this.format});
  final Uint8List image;
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
    final body = separateTags(s.text).body;
    final excerpt = body.isEmpty ? '' : ' — ${cutText(body, 110).text}';
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
    return _send(context, kind, pro: pro, quote: quote);
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
  static Future<bool> publishAsPost(BuildContext context, CardResult r, CardQuote quote, {Canal? canal, String? defiPostId}) async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _PostPublishPage(result: r, quote: quote, canal: canal, defiPostId: defiPostId)),
    );
    return done == true;
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
  const _PostPublishPage({required this.result, required this.quote, this.canal, this.defiPostId});
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
        title: Text(context.tr('Publier la carte'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: UserPostLookImageTab(
        canal: canal,
        defiPostId: defiPostId,
        initialImages: [result.image],
        initialDescription: result.caption,
        beforePublish: () => CardFlow.commit(context, CardKind.publish, pro: result.pro, quote: quote),
        onPublished: () => Navigator.of(context).pop(true),
      ),
    );
  }
}
