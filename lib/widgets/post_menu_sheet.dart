import 'package:afrotok/services/api/posts_api.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:afrotok/widgets/post_diffusion_sheet.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ads/gold_gate.dart';
import '../l10n/tr.dart';
import '../models/model_data.dart';
import '../pages/cards/card_entry.dart';
import '../pages/defi/defi_boost.dart';
import '../pages/defi/defi_convert.dart';
import '../pages/userPosts/reply_videos_page.dart';
import '../providers/authProvider.dart';
import '../services/api/commerce_api.dart';
import '../services/block_service.dart';
import '../services/post_download.dart';
import '../theme/app_colors.dart';
import 'commerce_card.dart';

/// Une ligne propre à l'écran qui ouvre le menu (par exemple « Partager », « Republier » et « Envoyer dans un chat » dans les vidéos verticales).
class PostMenuExtra {
  const PostMenuExtra({required this.icon, required this.label, required this.onTap, this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
}

/// MENU UNIQUE d'une publication (« ⋯ ») : le même dans le fil, les pages détail (post, vidéo) et les vidéos verticales (décision du 08/11/2026 : on ne retrouve plus
/// une option dans un écran et pas dans l'autre). Les lignes sont toujours dans le même ordre ; seules celles qui ne concernent pas la publication ou la personne sont absentes
/// (« Booster » pour l'auteur seulement, « Signaler » jamais pour sa propre publication…).
///
/// [onDelete] : confirmation et suppression, propres à chaque écran. [closePageAfterBlock] : les pages détail se ferment une fois la personne bloquée.
Future<void> showPostMenuSheet(
  BuildContext context, {
  required Post post,
  required bool isFavorite,
  required VoidCallback onToggleFavorite,
  required VoidCallback onDelete,
  List<PostMenuExtra> extras = const [],
  bool closePageAfterBlock = false,
  VoidCallback? onChanged,
}) {
  final me = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
  return showResponsiveBottomSheet(
    context: context,
    backgroundColor: AppColors.of(context).surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (sheet) => PostMenuSheetBody(
      pageContext: context,
      sheetContext: sheet,
      post: post,
      me: me,
      isFavorite: isFavorite,
      onToggleFavorite: onToggleFavorite,
      onDelete: onDelete,
      extras: extras,
      closePageAfterBlock: closePageAfterBlock,
      onChanged: onChanged,
    ),
  );
}

/// Contenu du menu (séparé pour pouvoir le tester sans passer par un écran complet).
class PostMenuSheetBody extends StatelessWidget {
  const PostMenuSheetBody({
    super.key,
    required this.pageContext,
    required this.sheetContext,
    required this.post,
    required this.me,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onDelete,
    this.extras = const [],
    this.closePageAfterBlock = false,
    this.onChanged,
  });

  final BuildContext pageContext;
  final BuildContext sheetContext;
  final Post post;
  final UserData me;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;
  final List<PostMenuExtra> extras;
  final bool closePageAfterBlock;
  final VoidCallback? onChanged;

  bool get _isOwner => post.user_id == me.id || post.user?.id == me.id;
  bool get _isAdmin => me.role == UserRole.ADM.name;

  void _close() => Navigator.pop(sheetContext);

  Widget _row(AppColors c, IconData icon, String text, Color color, VoidCallback onTap, {Key? key}) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 16))),
          ]),
        ),
      ),
    );
  }

  /// Signalement : un par personne, le serveur applique la règle ; on retient localement pour ne plus proposer la ligne.
  Future<void> _report({required bool admin, required String type}) async {
    _close();
    final ctx = pageContext;
    final c = AppColors.of(ctx);
    void say(String m, {bool error = false}) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(m, textAlign: TextAlign.center, style: TextStyle(color: error ? Colors.white : c.success)), backgroundColor: error ? Colors.red : null));
    }

    try {
      await PostsApi.report(post.id!, type: type);
      final list = type == 'wrong_category' ? (post.wrongCategoryReporterIds ??= []) : (post.reporterIds ??= []);
      if (me.id != null && !list.contains(me.id)) list.add(me.id!);
      onChanged?.call();
      say(admin
          ? (type == 'wrong_category' ? tr('Post modéré — hors catégorie, score à 5 %.') : tr('Post modéré — score réduit à 10 %.'))
          : (type == 'wrong_category' ? tr('Signalé comme hors catégorie.') : tr('Post signalé, merci ! Notre équipe va l\'examiner.')));
    } on ApiException catch (e) {
      say(e.status == 409 || e.code == 'already_reported' ? tr('Tu as déjà signalé ce post.') : tr('Échec du signalement, réessaie.'), error: !(e.status == 409));
    } catch (_) {
      say(tr('Échec du signalement, réessaie.'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final id = post.id;
    final isAd = post.isAdvertisement == true;
    final reported = post.reporterIds?.contains(me.id) ?? false;
    final reportedWrong = post.wrongCategoryReporterIds?.contains(me.id) ?? false;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (CardEntry.canMake(post, me))
              CardMenuTile(onTap: () {
                _close();
                CardEntry.openFromPost(pageContext, post);
              }),
            if (DefiConvert.canConvert(post, me))
              DefiMenuTile(onTap: () {
                _close();
                DefiConvert.openFromPost(pageContext, post);
              }),
            if ((_isOwner || _isAdmin) && !isAd)
              _row(c, Icons.rocket_launch_outlined, tr('Booster ce post'), const Color(0xFFFFB300), () {
                _close();
                Navigator.push(pageContext, MaterialPageRoute(builder: (_) => boostPageFor(post)));
              }, key: const ValueKey('menu_boost')),
            if (id != null && !isAd)
              _row(c, Icons.video_call_rounded, tr('Réponses en vidéo'), c.textPrimary, () {
                _close();
                Navigator.push(pageContext, MaterialPageRoute(builder: (_) => ReplyVideosPage(postId: id)));
              }, key: const ValueKey('menu_replies')),
            _row(c, isFavorite ? Icons.bookmark : Icons.bookmark_border, isFavorite ? tr('Retirer des favoris') : tr('Ajouter aux favoris'),
                isFavorite ? const Color(0xFFFFB300) : c.textPrimary, () {
              _close();
              onToggleFavorite();
            }, key: const ValueKey('menu_favorite')),
            if (id != null && !isAd)
              _row(c, Icons.insights_rounded, tr('Diffusion'), c.textPrimary, () {
                _close();
                showPostDiffusionSheet(pageContext, id);   // vagues de diffusion : visible par tous
              }, key: const ValueKey('menu_diffusion')),
            if (PostDownload.canDownload(post))
              _row(c, Icons.download_rounded, _isOwner ? tr('Télécharger (gratuit)') : tr('Télécharger'), c.success, () {
                _close();
                PostDownload.start(pageContext, post);
              }, key: const ValueKey('menu_download')),
            for (final e in extras)
              _row(c, e.icon, e.label, e.color ?? c.textPrimary, () {
                _close();
                e.onTap();
              }),
            if (_isOwner && id != null && !isAd)
              _row(c, Icons.shopping_bag_outlined, post.hasCommerce ? tr('Modifier la carte Commerce') : tr('Ajouter une carte Commerce'), c.textPrimary, () async {
                _close();
                if (!await GoldGate.feature(pageContext, me.id ?? '', 'commerce_card')) return;
                if (!pageContext.mounted) return;
                await showCommerceEditor(pageContext, id);
                try {
                  post.hasCommerce = await CommerceApi.get(id) != null;
                  onChanged?.call();
                } catch (_) {}
              }, key: const ValueKey('menu_commerce')),
            if (!_isOwner) ...[
              if (_isAdmin) ...[
                _row(c, Icons.gavel, tr('Modérer ce post'), Colors.orange.shade700, () => _report(admin: true, type: 'standard'), key: const ValueKey('menu_moderate')),
                _row(c, Icons.category_outlined, tr('Contenu hors catégorie (admin)'), Colors.deepOrange.shade700, () => _report(admin: true, type: 'wrong_category'), key: const ValueKey('menu_wrong_admin')),
              ] else ...[
                if (!reported) _row(c, Icons.flag_outlined, tr('Signaler'), c.textPrimary, () => _report(admin: false, type: 'standard'), key: const ValueKey('menu_report')),
                if (!reportedWrong) _row(c, Icons.category_outlined, tr('Contenu hors catégorie'), c.textSecondary, () => _report(admin: false, type: 'wrong_category'), key: const ValueKey('menu_wrong')),
              ],
              if (post.user_id != null)
                _row(c, Icons.block, tr('Bloquer cet utilisateur'), c.danger, () async {
                  _close();
                  final blocked = await confirmAndBlockUser(pageContext, userId: post.user_id!, pseudo: post.user?.pseudo, postId: post.id);
                  if (blocked && closePageAfterBlock && pageContext.mounted) Navigator.pop(pageContext);
                }, key: const ValueKey('menu_block')),
            ],
            if (_isOwner || _isAdmin)
              _row(c, Icons.delete, tr('Supprimer'), c.danger, () {
                _close();
                onDelete();
              }, key: const ValueKey('menu_delete')),
            const SizedBox(height: 4),
            Divider(height: 1, color: c.textSecondary.withOpacity(0.25)),
            _row(c, Icons.cancel, tr('Annuler'), c.textSecondary, _close, key: const ValueKey('menu_cancel')),
          ]),
        ),
      ),
    );
  }
}
