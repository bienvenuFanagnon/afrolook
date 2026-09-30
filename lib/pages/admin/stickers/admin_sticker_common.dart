import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_colors.dart';
import '../../user/profile/retraitAdmin/userAllDetails.dart';
import 'admin_sticker_detail_page.dart';

/// Outils partagés des pages admin « Stickers » (textes en français simple, comme les autres pages admin).

final Map<String, String> _pseudoCache = {};
final Map<String, String> _packNameCache = {};

String stickerDate(dynamic v) {
  var n = (v as num?)?.toInt() ?? 0;
  if (n > 100000000000000) n ~/= 1000;
  if (n <= 0) return '—';
  return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(n));
}

String stickerStatusLabel(String s) {
  switch (s) {
    case 'active':
      return 'Publié';
    case 'pending':
      return 'En attente';
    case 'rejected':
      return 'Refusé';
    case 'removed':
      return 'Retiré';
    default:
      return s.isEmpty ? '—' : s;
  }
}

Color stickerStatusColor(AppColors c, String s) {
  switch (s) {
    case 'active':
      return c.success;
    case 'pending':
      return c.warning;
    case 'rejected':
    case 'removed':
      return c.danger;
    default:
      return c.textSecondary;
  }
}

/// Légende française, sinon première légende disponible.
String stickerCaption(Map<String, dynamic> d) {
  final caps = d['captions'];
  if (caps is Map && caps.isNotEmpty) {
    final fr = (caps['fr'] ?? '').toString();
    if (fr.isNotEmpty) return fr;
    for (final v in caps.values) {
      if (v.toString().isNotEmpty) return v.toString();
    }
  }
  return '';
}

Future<String> stickerPseudo(String? uid) async {
  if (uid == null || uid.isEmpty) return '—';
  if (uid == 'afrolook') return 'Afrolook';
  final cached = _pseudoCache[uid];
  if (cached != null) return cached;
  try {
    final u = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
    final p = (u.data()?['pseudo'] ?? '').toString();
    final v = p.isEmpty ? uid : '@$p';
    _pseudoCache[uid] = v;
    return v;
  } catch (_) {
    return uid;
  }
}

Future<String> stickerPackName(String? packId) async {
  if (packId == null || packId.isEmpty) return '—';
  final cached = _packNameCache[packId];
  if (cached != null) return cached;
  try {
    final p = await FirebaseFirestore.instance.collection('StickerPacks').doc(packId).get();
    final v = (p.data()?['name'] ?? packId).toString();
    _packNameCache[packId] = v;
    return v;
  } catch (_) {
    return packId;
  }
}

void stickerOpenUser(BuildContext context, String? uid) {
  if (uid == null || uid.isEmpty || uid == 'afrolook') return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => UserManagementPage(userId: uid)));
}

/// Texte asynchrone : pseudo d'un utilisateur.
class StickerPseudoText extends StatelessWidget {
  final String? uid;
  final TextStyle? style;
  const StickerPseudoText(this.uid, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: stickerPseudo(uid),
      builder: (_, s) => Text(s.data ?? '…', maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    );
  }
}

class StickerPackNameText extends StatelessWidget {
  final String? packId;
  final TextStyle? style;
  const StickerPackNameText(this.packId, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: stickerPackName(packId),
      builder: (_, s) => Text(s.data ?? '…', maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    );
  }
}

/// Miniature d'un sticker ; [animated] charge l'animation par-dessus la miniature.
class StickerThumbBox extends StatelessWidget {
  final Map<String, dynamic> data;
  final double size;
  final bool animated;
  const StickerThumbBox(this.data, {super.key, this.size = 56, this.animated = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final thumb = (data['thumbUrl'] ?? '').toString();
    final url = (data['url'] ?? '').toString();
    final src = animated && url.isNotEmpty ? url : (thumb.isNotEmpty ? thumb : url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: c.surfaceVariant,
        child: src.isEmpty
            ? Icon(Icons.image_not_supported_outlined, color: c.textSecondary)
            : Image.network(
                src,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => thumb.isNotEmpty && src != thumb
                    ? Image.network(thumb, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: c.textSecondary))
                    : Icon(Icons.broken_image_outlined, color: c.textSecondary),
              ),
      ),
    );
  }
}

Widget stickerBadge(Color color, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );

/// Demande un motif ; retourne null si annulé. Si [required], le motif ne peut pas être vide.
Future<String?> stickerAskReason(BuildContext context, String title, {bool required = true}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      String? err;
      return StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: Text(title),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              maxLength: 200,
              maxLines: 3,
              decoration: InputDecoration(hintText: 'Motif (visible par le créateur)', errorText: err),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            TextButton(
              onPressed: () {
                final v = ctrl.text.trim();
                if (required && v.isEmpty) {
                  setS(() => err = 'Le motif est obligatoire');
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: const Text('Confirmer'),
            ),
          ],
        );
      });
    },
  );
}

Future<bool> stickerConfirm(BuildContext context, String title, String message) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmer')),
      ],
    ),
  );
  return r == true;
}

/// Appelle `adminStickerAction` ; affiche l'erreur en rouge et retourne false en cas d'échec.
Future<bool> stickerAdminAction(
  BuildContext context, {
  String? packId,
  String? stickerId,
  required String action,
  String? reason,
}) async {
  try {
    await FirebaseFunctions.instance.httpsCallable('adminStickerAction').call({
      if (packId != null) 'packId': packId,
      if (stickerId != null) 'stickerId': stickerId,
      'action': action,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
    return true;
  } on FirebaseFunctionsException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec : ${e.message ?? e.code}'), backgroundColor: Colors.red));
    }
    return false;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec : $e'), backgroundColor: Colors.red));
    }
    return false;
  }
}

void stickerToast(BuildContext context, String msg) {
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Comparaison côte à côte d'un sticker copié et de son sticker d'origine (`Stickers/{copyOf}`).
class StickerCompareView extends StatelessWidget {
  final String stickerId;
  final Map<String, dynamic> sticker;
  const StickerCompareView({super.key, required this.stickerId, required this.sticker});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final originId = (sticker['copyOf'] ?? '').toString();
    if (originId.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('Stickers').doc(originId).get(),
      builder: (ctx, snap) {
        final origin = snap.data?.data();
        final myAt = (sticker['createdAt'] as num?)?.toInt() ?? 0;
        final orAt = (origin?['createdAt'] as num?)?.toInt() ?? 0;
        String verdict = '';
        if (origin != null && myAt > 0 && orAt > 0) {
          verdict = orAt <= myAt
              ? 'Le sticker d\'origine a été déposé en premier (${stickerDate(orAt)}).'
              : 'Ce sticker a été déposé avant celui signalé comme origine (${stickerDate(myAt)} contre ${stickerDate(orAt)}).';
        }
        Widget side(String title, Map<String, dynamic> d, String? creatorId, {Color? color}) => Expanded(
              child: Column(children: [
                Text(title, style: TextStyle(color: color ?? c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                StickerThumbBox(d, size: 110, animated: true),
                const SizedBox(height: 6),
                StickerPseudoText(creatorId, style: TextStyle(color: c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text(stickerDate(d['createdAt']), style: TextStyle(color: c.textSecondary, fontSize: 11)),
              ]),
            );
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.danger.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.danger.withOpacity(0.35)),
          ),
          child: Column(children: [
            Text('Copie possible', style: TextStyle(color: c.danger, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 8),
            if (snap.connectionState != ConnectionState.done)
              const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
            else if (origin == null)
              Text('Le sticker d\'origine est introuvable ($originId).', style: TextStyle(color: c.textSecondary, fontSize: 12.5))
            else
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                side('SOUMIS', sticker, sticker['creatorId']?.toString(), color: c.danger),
                const SizedBox(width: 8),
                side('ORIGINE', origin, (origin['creatorId'] ?? sticker['copyOfCreator'])?.toString(), color: c.success),
              ]),
            if (verdict.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(verdict, textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 12.5)),
            ],
            if (origin != null)
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminStickerDetailPage(stickerId: originId))),
                child: const Text('Voir la fiche du sticker d\'origine'),
              ),
          ]),
        );
      },
    );
  }
}
