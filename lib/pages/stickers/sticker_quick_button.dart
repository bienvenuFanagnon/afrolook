import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/services/stickers/sticker_models.dart';
import 'package:afrotok/services/utils/abonnement_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'sticker_picker_sheet.dart';
import 'sticker_widgets.dart';

/// Bouton sticker des champs de commentaire rapide : ouvre le sélecteur (ou l'invitation Premium pour un compte
/// gratuit) et renvoie le sticker choisi ; l'appelant l'envoie comme commentaire, avec le texte déjà saisi.
class StickerQuickButton extends StatelessWidget {
  final String? postId;
  final ValueChanged<StickerItem> onPicked;
  final double size;
  final Color? color;

  const StickerQuickButton({super.key, required this.postId, required this.onPicked, this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<UserAuthProvider>(context, listen: false);
    final tint = color ?? kStickerGold;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        FocusScope.of(context).unfocus();
        final me = auth.loginUserData;
        final allowed = AbonnementUtils.isPremiumActive(me.abonnement) || me.role == UserRole.ADM.name;
        if (!allowed) {
          await showStickerPremiumInvite(context);
          return;
        }
        final picked = await showStickerPicker(context, userId: me.id ?? '', postId: postId);
        if (picked != null) onPicked(picked);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.sticky_note_2_rounded, size: size, color: tint),
      ),
    );
  }
}
