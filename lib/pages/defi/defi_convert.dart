import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../../services/utils/abonnement_utils.dart';
import '../userPosts/postWidgets/defi_config_section.dart';
import 'defi_ui.dart';

const Color _defiOrange = Color(0xFFFF9500);

/// Transformer un post déjà publié en DÉFI, depuis le menu « ⋯ » du post.
/// Mêmes règles qu'un nouveau DÉFI (cagnotte débitée sur le solde, frais de participation et de vote, date de fin, gagnants) :
/// la Cloud Function `handleDefiAction` (action « convert ») contrôle tout côté serveur.
class DefiConvert {
  DefiConvert._();

  /// Seul l'auteur le peut, et seulement sur un post ordinaire non monétisé : ni publicité, ni réponse à un DÉFI, ni DÉFI existant.
  static bool canConvert(Post post, UserData me) {
    if ((post.id ?? '').isEmpty || post.user_id != me.id) return false;
    if ((post.type ?? PostType.POST.name) != PostType.POST.name) return false;
    if (post.isAdvertisement == true || post.defiResponseToPostId != null) return false;
    if (post.status != null && post.status != PostStatus.VALIDE.name) return false;
    // un post monétisé (ou ancien, sans choix enregistré) ne devient jamais un DÉFI : aucune vue de DÉFI n'est monétisée
    if (post.isMonetized) return false;
    final t = post.dataType;
    return t == PostDataType.TEXT.name || t == PostDataType.IMAGE.name || t == PostDataType.VIDEO.name || t == PostDataType.AUDIO.name;
  }

  static Future<bool> openFromPost(BuildContext context, Post post) async {
    final done = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => DefiConvertPage(post: post)));
    return done == true;
  }
}

/// Ligne « Transformer en défi » pour les menus de post (même gabarit que « Créer une carte Afrolook »).
class DefiMenuTile extends StatelessWidget {
  const DefiMenuTile({super.key, required this.onTap, this.color});
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(children: [
            const Icon(Icons.emoji_events_rounded, color: _defiOrange, size: 20),
            const SizedBox(width: 12),
            Text(context.tr('Transformer en défi'), style: TextStyle(color: color ?? c.textPrimary, fontSize: 16)),
          ]),
        ),
      ),
    );
  }
}

class DefiConvertPage extends StatefulWidget {
  const DefiConvertPage({super.key, required this.post});
  final Post post;

  @override
  State<DefiConvertPage> createState() => _DefiConvertPageState();
}

class _DefiConvertPageState extends State<DefiConvertPage> {
  DefiConfig? _config;
  bool _busy = false;
  late final TextEditingController _desc = TextEditingController(text: widget.post.description ?? '');

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  /// Même plafond de caractères qu'un post ordinaire (gratuit 300, premium 3 000, Gold et admin 5 000).
  int get _maxChars {
    final me = context.read<UserAuthProvider>().loginUserData;
    if (me.role == UserRole.ADM.name || AbonnementUtils.isGold(me.abonnement)) return 5000;
    return AbonnementUtils.isPremiumActive(me.abonnement) ? 3000 : 300;
  }

  String? get _thumb {
    final p = widget.post;
    if ((p.thumbnail ?? '').isNotEmpty) return p.thumbnail;
    final imgs = (p.images ?? const <String>[]).where((u) => u.isNotEmpty);
    return imgs.isEmpty ? null : imgs.first;
  }

  Future<void> _launch() async {
    final config = _config;
    if (config == null || _busy) return;
    final auth = context.read<UserAuthProvider>();
    if (config.cagnottePieces > (auth.loginUserData.giftCoinsBalance ?? 0)) {
      DefiDialogs.insufficientBalance(context, isVote: false, isCreation: true);
      return;
    }
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(ctx.tr('Lancer ce défi ?'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(
          config.cagnottePieces > 0
              ? ctx.tr('{n} 🪙 seront prélevés sur ton solde pour la cagnotte. Ton post devient un défi, annoncé à toute la communauté. Tu ne pourras plus changer sa configuration.', {'n': config.cagnottePieces})
              : ctx.tr('Ton post devient un défi, annoncé à toute la communauté. Tu ne pourras plus changer sa configuration.'),
          style: TextStyle(color: c.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Lancer le défi'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('handleDefiAction').call({
        'action': 'convert',
        'postId': widget.post.id,
        'defi_config': config.toJson(),
        if (_desc.text.trim() != (widget.post.description ?? '').trim()) 'description': _desc.text.trim(),
      });
      if (!mounted) return;
      auth.refreshUserData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Ton post est devenu un défi 🏆 La communauté est prévenue.'))));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        DefiDialogs.handleError(context, e, isVote: false, isCreation: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final p = widget.post;
    final balance = context.watch<UserAuthProvider>().loginUserData.giftCoinsBalance ?? 0;
    final thumb = _thumb;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: Text(context.tr('Transformer en défi'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (thumb != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(width: 72, height: 72, child: CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)),
                  ),
                if (thumb != null) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (p.description ?? '').trim().isEmpty ? context.tr('Ton post') : p.description!.trim(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.35),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(
                context.tr('Les autres répondent à ton post en participant, et la communauté vote. Mêmes règles qu\'un nouveau défi : la cagnotte est prélevée sur ton solde, tu fixes la date de fin, les frais de participation et de vote, et le nombre de gagnants.'),
                style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.45),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _desc,
                maxLines: 4,
                minLines: 2,
                maxLength: _maxChars,
                style: TextStyle(color: c.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: context.tr('Description du défi'),
                  helperText: context.tr('Tu peux la changer avant de lancer le défi.'),
                  helperMaxLines: 2,
                  filled: true,
                  fillColor: c.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
                ),
              ),
            ),
            DefiConfigSection(onChanged: (config) => setState(() => _config = config)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(context.tr('Ton solde : {b} 🪙', {'b': balance}), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _defiOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: _config == null || _busy ? null : _launch,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.emoji_events_rounded),
                label: Text(context.tr('Lancer le défi'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            if (_config == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(context.tr('Choisis une date de fin pour lancer le défi.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
