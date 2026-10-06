import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/tr.dart';
import '../theme/app_colors.dart';
import '../utils/responsive_sheet.dart';

const String kAfrolookPlayStoreUrl = 'https://play.google.com/store/apps/details?id=com.afrotok.afrotok';
const String kAfrolookAppStoreUrl = 'https://apps.apple.com/app/id6811423047';

/// Menu « Partager l'application » : l'utilisateur choisit le lien à envoyer (Android, iPhone ou les deux).
/// Les liens sont fixes : aucun chargement, le partage s'ouvre tout de suite.
Future<void> showShareAppSheet(BuildContext context) {
  final c = AppColors.of(context);
  return showResponsiveBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 14),
          Text(context.tr("Partager l'application"), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 4),
          Text(
            context.tr('Choisis le lien selon le téléphone de ton ami.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          _option(ctx, c, Icons.android_rounded, context.tr('Lien Android (Google Play)'), kAfrolookPlayStoreUrl),
          _option(ctx, c, Icons.apple_rounded, context.tr('Lien iPhone (App Store)'), kAfrolookAppStoreUrl),
          _option(ctx, c, Icons.devices_rounded, context.tr('Les deux liens'), null),
        ]),
      ),
    ),
  );
}

Widget _option(BuildContext ctx, AppColors c, IconData icon, String label, String? url) {
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
    leading: CircleAvatar(backgroundColor: c.primary.withOpacity(0.15), child: Icon(icon, color: c.primary)),
    title: Text(label, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
    trailing: Icon(Icons.ios_share_rounded, size: 20, color: c.textSecondary),
    onTap: () {
      final box = ctx.findRenderObject() as RenderBox?;
      final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
      final invite = ctx.tr('Rejoins-moi sur Afrolook !');
      final text = url != null
          ? '$invite\n$url'
          : '$invite\n${ctx.tr('Android')} : $kAfrolookPlayStoreUrl\n${ctx.tr('iPhone')} : $kAfrolookAppStoreUrl';
      Navigator.pop(ctx);
      Share.share(text, sharePositionOrigin: origin);
    },
  );
}
