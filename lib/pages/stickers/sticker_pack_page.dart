import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/coin_checkout.dart';
import '../../services/stickers/sticker_models.dart';
import '../../services/stickers/sticker_service.dart';
import '../../theme/app_colors.dart';
import 'sticker_widgets.dart';

/// Détail d'un pack : tous les stickers, achat si payant, signalement d'une copie.
/// Renvoie (Navigator.pop) le sticker touché quand il est utilisable et que l'envoi est possible.
class StickerPackPage extends StatefulWidget {
  final StickerPack pack;
  final StickerCreatorInfo? creator;

  /// Faux quand le compte ne peut pas envoyer de stickers en commentaire (la page reste consultable).
  final bool canSend;

  const StickerPackPage({super.key, required this.pack, this.creator, this.canSend = true});

  @override
  State<StickerPackPage> createState() => _StickerPackPageState();
}

class _StickerPackPageState extends State<StickerPackPage> {
  final StickerService _service = StickerService.instance;
  List<StickerItem> _stickers = [];
  StickerCreatorInfo? _creator;
  bool _loading = true;
  bool _failed = false;
  bool _owned = false;
  bool _buying = false;

  StickerPack get _pack => widget.pack;
  String get _uid => Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id ?? '';

  /// Utilisable : gratuit, acheté, ou pack dont on est le créateur (comme le contrôle serveur).
  bool get _usable => _pack.isFree || _owned || _pack.creatorId == _uid;

  @override
  void initState() {
    super.initState();
    _creator = widget.creator;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await Future.wait([
        _service.loadPackStickers(_pack.id),
        _service.loadOwnedPackIds(_uid),
        if (_creator == null) _service.resolveCreators([_pack.creatorId]),
      ]);
      if (!mounted) return;
      setState(() {
        _stickers = results[0] as List<StickerItem>;
        _owned = (results[1] as Set<String>).contains(_pack.id);
        if (_creator == null) _creator = (results[2] as Map<String, StickerCreatorInfo>)[_pack.creatorId];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _buy() async {
    if (_buying) return;
    setState(() => _buying = true);
    final lang = Localizations.localeOf(context).languageCode;
    final ok = await CoinCheckout.pay(
      context,
      kind: 'sticker_pack',
      label: context.tr('Pack « {a} »', {'a': _pack.localizedName(lang)}),
      coins: _pack.priceCoins,
      refId: _pack.id,
    );
    if (!mounted) return;
    var owned = ok;
    if (!ok) {
      // `already-exists` (pack déjà possédé) : on relit les achats pour débloquer l'affichage.
      final ids = await _service.loadOwnedPackIds(_uid);
      owned = ids.contains(_pack.id);
    }
    if (!mounted) return;
    setState(() {
      _buying = false;
      if (owned) _owned = true;
    });
    if (ok) _snack(context.tr('Pack acheté : tu peux l\'utiliser en commentaire'));
  }

  void _onTap(StickerItem s) {
    if (!_usable) {
      _preview(s);
      return;
    }
    if (!widget.canSend) {
      _snack(context.tr('Les stickers sont réservés aux abonnés Premium'));
      return;
    }
    Navigator.pop(context, s);
  }

  /// Aperçu en grand avec le nom du créateur en filigrane.
  void _preview(StickerItem s) {
    final c = AppColors.of(context);
    final pseudo = (_creator?.pseudo ?? '').isEmpty ? '' : '@${_creator!.pseudo}';
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    StickerImage(sticker: s),
                    if (pseudo.isNotEmpty) Positioned.fill(child: IgnorePointer(child: _Watermark(text: pseudo))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(context.tr('Aperçu : achète le pack pour utiliser ce sticker'),
                  textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _report(s);
                    },
                    icon: Icon(Icons.flag_outlined, size: 17, color: c.textSecondary),
                    label: Text(context.tr('Signaler une copie'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                  ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Fermer'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// « Signaler une copie » : petite fenêtre de confirmation avec une note facultative.
  Future<void> _report(StickerItem s) async {
    final c = AppColors.of(context);
    final noteCtrl = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(context.tr('Signaler une copie'),
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 72, height: 72, child: StickerImage(sticker: s, loadAnimation: false)),
            const SizedBox(height: 10),
            Text(context.tr('Ce sticker copie-t-il l\'œuvre de quelqu\'un d\'autre ? L\'équipe Afrolook vérifiera ton signalement.'),
                style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.35)),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              maxLength: 200,
              maxLines: 2,
              style: TextStyle(color: c.textPrimary, fontSize: 13.5),
              decoration: InputDecoration(
                hintText: context.tr('Précision (facultatif)'),
                hintStyle: TextStyle(color: c.textSecondary),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Annuler'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            child: Text(context.tr('Signaler')),
          ),
        ],
      ),
    );
    final note = noteCtrl.text;
    noteCtrl.dispose();
    if (go != true || !mounted) return;
    try {
      await _service.reportCopy(stickerId: s.id, note: note);
      if (mounted) _snack(context.tr('Merci, ton signalement a été envoyé'));
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _snack(e.code == 'unavailable' || e.code == 'unimplemented'
          ? context.tr('Signalement indisponible pour le moment')
          : (e.message ?? context.tr('Signalement impossible')));
    } catch (_) {
      if (mounted) _snack(context.tr('Signalement impossible. Vérifie ta connexion.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final pseudo = _creator?.pseudo ?? '';
    return Scaffold(
      backgroundColor: c.surface,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(_pack.localizedName(lang),
            style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Flexible(
                  child: Text(pseudo.isEmpty ? '' : context.tr('par @{a}', {'a': pseudo}),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 13)),
                ),
                if (_creator?.verified == true) ...[
                  const SizedBox(width: 4),
                  Tooltip(message: context.tr('Créateur vérifié'), child: const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF1DA1F2))),
                ],
                const Spacer(),
                Text(context.tr('{a} stickers', {'a': _stickers.isEmpty ? _pack.stickerCount : _stickers.length}),
                    style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: c.primary, strokeWidth: 2.5))
                : _failed
                    ? Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(context.tr('Impossible de charger les stickers.'), style: TextStyle(color: c.textSecondary)),
                          TextButton(onPressed: _load, child: Text(context.tr('Réessayer'), style: TextStyle(color: c.primary))),
                        ]),
                      )
                    : _stickers.isEmpty
                        ? Center(child: Text(context.tr('Aucun sticker pour le moment'), style: TextStyle(color: c.textSecondary)))
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                            cacheExtent: 60,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                            itemCount: _stickers.length,
                            itemBuilder: (_, i) {
                              final s = _stickers[i];
                              return _PackCell(
                                sticker: s,
                                locked: !_usable,
                                watermark: pseudo.isEmpty ? '' : '@$pseudo',
                                onTap: () => _onTap(s),
                                onLongPress: () => _report(s),
                              );
                            },
                          ),
          ),
          if (!_loading && !_failed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(context.tr('Appui long sur un sticker : signaler une copie'),
                  style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: _usable
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: c.success.withOpacity(0.12), borderRadius: BorderRadius.circular(24)),
                        child: Text(
                          _pack.isFree ? context.tr('Pack gratuit : touche un sticker pour l\'envoyer') : context.tr('Pack acheté'),
                          style: TextStyle(color: c.success, fontWeight: FontWeight.w700, fontSize: 13.5),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kStickerGold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: _buying ? null : _buy,
                        child: _buying
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                context.tr('Acheter — {a} pièces', {'a': CoinCheckout.fmt(_pack.priceCoins)}),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackCell extends StatelessWidget {
  final StickerItem sticker;
  final bool locked;
  final String watermark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PackCell({
    required this.sticker,
    required this.locked,
    required this.watermark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(color: c.surfaceVariant.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(4),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: locked ? 0.4 : 1,
              child: ColorFiltered(
                colorFilter: locked
                    ? const ColorFilter.matrix(<double>[
                        0.33, 0.33, 0.33, 0, 0, //
                        0.33, 0.33, 0.33, 0, 0,
                        0.33, 0.33, 0.33, 0, 0,
                        0, 0, 0, 1, 0,
                      ])
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: StickerImage(sticker: sticker, loadAnimation: !locked),
              ),
            ),
            if (locked) ...[
              if (watermark.isNotEmpty) Positioned.fill(child: IgnorePointer(child: _Watermark(text: watermark, small: true))),
              Positioned(right: 0, bottom: 0, child: Icon(Icons.lock_rounded, size: 16, color: c.textPrimary)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nom du créateur en diagonale, semi-transparent, par-dessus l'aperçu.
class _Watermark extends StatelessWidget {
  final String text;
  final bool small;
  const _Watermark({required this.text, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.rotate(
        angle: -0.5,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: small ? 9 : 22,
            fontWeight: FontWeight.w900,
            color: Colors.white.withOpacity(0.55),
            shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
          ),
        ),
      ),
    );
  }
}
