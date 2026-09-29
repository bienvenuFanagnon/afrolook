import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../models/coin_pack.dart';
import '../providers/authProvider.dart';
import '../providers/coin_gift_provider.dart';
import '../theme/app_colors.dart';
import 'like_coins_helper.dart';
import 'pseudo_tag.dart';
import 'support_modal.dart';

/// Cadeau à l'auteur d'un commentaire (ou d'une réponse) : grille de cadeaux, solde, envoi
/// par le serveur (sendCommentGift), puis fenêtre « Tu viens de soutenir @pseudo ».
Future<void> showCommentGiftSheet(
  BuildContext context, {
  required String commentId,
  String? replyId,
  required String authorPseudo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CommentGiftSheet(commentId: commentId, replyId: replyId, authorPseudo: authorPseudo, parent: context),
  );
}

class _CommentGiftSheet extends StatefulWidget {
  final String commentId;
  final String? replyId;
  final String authorPseudo;
  final BuildContext parent;
  const _CommentGiftSheet({required this.commentId, required this.replyId, required this.authorPseudo, required this.parent});

  @override
  State<_CommentGiftSheet> createState() => _CommentGiftSheetState();
}

class _CommentGiftSheetState extends State<_CommentGiftSheet> {
  bool _sending = false;
  late final List<CoinPack> _packs = CoinPack.giftPacks.take(15).toList();

  Future<void> _send(CoinPack pack) async {
    if (_sending) return;
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    final parent = widget.parent;
    if (coinProvider.giftCoinsBalance < pack.coins) {
      Navigator.of(context).pop();
      showInsufficientCoinsForLikeDialog(context: parent, user: auth.loginUserData, coinProvider: coinProvider, authProvider: auth);
      return;
    }
    setState(() => _sending = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('sendCommentGift').call({
        'commentId': widget.commentId,
        if (widget.replyId != null) 'replyId': widget.replyId,
        'coins': pack.coins,
        'giftIcon': pack.icon,
        'giftLabel': pack.label,
      });
      final uid = auth.loginUserData.id;
      if (uid != null) await coinProvider.refreshBalance(uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (parent.mounted) {
        showSupportedModal(parent, pseudo: widget.authorPseudo, emoji: pack.icon, detail: '${pack.label} · ${pack.coins} 🪙');
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      if (e.code == 'resource-exhausted') {
        Navigator.of(context).pop();
        showInsufficientCoinsForLikeDialog(context: parent, user: auth.loginUserData, coinProvider: coinProvider, authProvider: auth);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? context.tr('Envoi impossible'))));
      }
    } catch (_) {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final coinProvider = Provider.of<CoinGiftUserProvider>(context);
    final gold = c.isDark ? const Color(0xFFF5C542) : const Color(0xFFD99A00);
    final sheet = Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .7),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
      decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Row(children: [
          Text(context.tr('Offrir un cadeau à'), style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Flexible(child: PseudoTag(label: '@${widget.authorPseudo}', style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800))),
          const Spacer(),
          Text('🪙 ${coinProvider.giftCoinsBalance}', style: TextStyle(color: gold, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 12),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: _packs.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.15),
            itemBuilder: (_, i) {
              final p = _packs[i];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _sending ? null : () => _send(p),
                child: Container(
                  decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(14)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(p.icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 2),
                    Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                    Text('${p.coins} 🪙', style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.w900)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );

    // Pendant l'envoi : voile + roue + message, la grille n'est plus touchable
    return Stack(children: [
      sheet,
      if (_sending)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: c.surface.withOpacity(.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 46, height: 46, child: CircularProgressIndicator(strokeWidth: 4, color: gold)),
              const SizedBox(height: 16),
              Text(context.tr('Envoi du cadeau en cours…'),
                  style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(context.tr('Ne ferme pas cette fenêtre'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ]),
          ),
        ),
    ]);
  }
}
