import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import 'chronique_flow.dart';
import 'create_hub_page.dart';

/// Menu du bouton « + » : deux gros choix, créer un post ou passer en live. Le choix du type de post (vidéo, photo, audio, texte, carte) vient ensuite,
/// sur l'écran « Que créer ? » ([CreateHubPage]).
Future<void> showCreateMenu(BuildContext context) {
  final nav = Navigator.of(context);
  final pseudo = (context.read<UserAuthProvider>().loginUserData.pseudo ?? '').trim();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => CreateMenuSheet(
      pseudo: pseudo,
      onCreate: () {
        Navigator.pop(ctx);
        nav.push(MaterialPageRoute(builder: (_) => const CreateHubPage()));
      },
      onChronique: () {
        Navigator.pop(ctx);
        nav.push(MaterialPageRoute(builder: (_) => const CreateHubPage(chronique: ChroniqueKind.normal)));
      },
      onBusiness: () {
        Navigator.pop(ctx);
        nav.push(MaterialPageRoute(builder: (_) => const CreateHubPage(chronique: ChroniqueKind.business)));
      },
      onLive: () {
        Navigator.pop(ctx);
        nav.pushNamed('/create_live');
      },
    ),
  );
}

class CreateMenuSheet extends StatelessWidget {
  const CreateMenuSheet({super.key, this.pseudo = '', required this.onCreate, this.onChronique, this.onBusiness, required this.onLive});

  /// Prénom ou pseudo affiché dans le titre (vide = titre sans nom).
  final String pseudo;
  final VoidCallback onCreate;

  /// Chronique de 24 h et chronique business : elles ouvrent le Studio comme un post (null = choix masqué).
  final VoidCallback? onChronique;
  final VoidCallback? onBusiness;
  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 30, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 14),
            const _BrandBar(),
            const SizedBox(height: 14),
            Text(
              pseudo.isEmpty ? context.tr('Que veux-tu faire ?') : context.tr('Que veux-tu faire, {a} ?', {'a': pseudo}),
              style: TextStyle(color: c.textPrimary, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -.2),
            ),
            const SizedBox(height: 4),
            Text(context.tr('Choisis ton format, on s\'occupe du reste.'), style: TextStyle(color: c.textSecondary, fontSize: 13.5)),
            const SizedBox(height: 16),
            _MenuCard(
              key: const ValueKey('menu_create'),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.accent, c.accent.withOpacity(.82)]),
              iconBg: const Color(0x24000000),
              icon: Icons.add_rounded,
              iconColor: c.onAccent,
              title: context.tr('Publication'),
              subtitle: context.tr('Photo, vidéo, audio ou texte dans le fil'),
              titleColor: c.onAccent,
              subtitleColor: c.onAccent.withOpacity(.72),
              onTap: onCreate,
            ),
            if (onChronique != null) ...[
              const SizedBox(height: 10),
              _MenuCard(
                key: const ValueKey('menu_chronique'),
                color: c.surfaceVariant,
                border: c.border,
                iconBg: c.accent,
                icon: Icons.history_toggle_off_rounded,
                iconColor: c.onAccent,
                title: context.tr('Chronique (24 h)'),
                subtitle: context.tr('Ouvre le Studio : montage, musique, texte, épinglage'),
                titleColor: c.textPrimary,
                subtitleColor: c.textSecondary,
                onTap: onChronique!,
              ),
            ],
            if (onBusiness != null) ...[
              const SizedBox(height: 10),
              _MenuCard(
                key: const ValueKey('menu_business'),
                color: c.surfaceVariant,
                border: c.border,
                iconBg: c.primary,
                icon: Icons.storefront_rounded,
                iconColor: Colors.white,
                title: context.tr('Chronique business'),
                subtitle: context.tr('Vends un produit : carte de vente, lien, WhatsApp, appel'),
                titleColor: c.textPrimary,
                subtitleColor: c.textSecondary,
                onTap: onBusiness!,
              ),
            ],
            const SizedBox(height: 10),
            _MenuCard(
              key: const ValueKey('menu_live'),
              color: c.surfaceVariant,
              border: c.border,
              iconBg: c.danger,
              icon: Icons.sensors_rounded,
              iconColor: Colors.white,
              title: context.tr('Live'),
              subtitle: context.tr('En direct, avec cadeaux ou vente'),
              titleColor: c.textPrimary,
              subtitleColor: c.textSecondary,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(7)),
                child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: .8)),
              ),
              onTap: onLive,
            ),
          ]),
        ),
      ),
    );
  }
}

/// Fine barre aux trois couleurs d'Afrolook (vert, jaune, rouge) : la signature du réseau.
class _BrandBar extends StatelessWidget {
  const _BrandBar();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 4,
        width: 64,
        child: Row(children: [
          Expanded(flex: 6, child: ColoredBox(color: c.primary)),
          Expanded(flex: 3, child: ColoredBox(color: c.accent)),
          Expanded(flex: 2, child: ColoredBox(color: c.danger)),
        ]),
      ),
    );
  }
}

class _MenuCard extends StatefulWidget {
  const _MenuCard({
    super.key,
    this.gradient,
    this.color,
    this.border,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
    this.trailing,
    required this.onTap,
  });

  final Gradient? gradient;
  final Color? color;
  final Color? border;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _down ? .97 : 1,
      duration: const Duration(milliseconds: 110),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            color: widget.gradient == null ? widget.color : null,
            borderRadius: BorderRadius.circular(20),
            border: widget.border == null ? null : Border.all(color: widget.border!),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onHighlightChanged: (v) => setState(() => _down = v),
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: widget.iconBg, borderRadius: BorderRadius.circular(16)),
                  child: Icon(widget.icon, color: widget.iconColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.title, style: TextStyle(color: widget.titleColor, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(widget.subtitle, style: TextStyle(color: widget.subtitleColor, fontSize: 12.5, height: 1.3)),
                  ]),
                ),
                if (widget.trailing != null) widget.trailing! else Icon(Icons.chevron_right_rounded, color: widget.subtitleColor),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
