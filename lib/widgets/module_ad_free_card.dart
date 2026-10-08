import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ads/ad_config.dart';
import '../ads/module_ads.dart';
import '../l10n/tr.dart';
import '../pages/contes/conte_style.dart';
import '../providers/authProvider.dart';
import '../services/coin_checkout.dart';
import '../theme/app_colors.dart';

enum ModuleAdFreeStyle { app, conte }

/// Offre « Sans pub pendant 30 jours » pour Quiz, Étude et Contes, payée en pièces. Quand le pass est actif,
/// la carte indique la date de fin. Les pubs choisies pour débloquer un contenu ne sont pas concernées.
class ModuleAdFreeCard extends StatefulWidget {
  const ModuleAdFreeCard({super.key, this.style = ModuleAdFreeStyle.app, this.margin = EdgeInsets.zero});
  final ModuleAdFreeStyle style;
  final EdgeInsets margin;

  @override
  State<ModuleAdFreeCard> createState() => _ModuleAdFreeCardState();
}

class _ModuleAdFreeCardState extends State<ModuleAdFreeCard> {
  ModuleAdFreeOffer _offer = const ModuleAdFreeOffer();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ModuleAds.changes.addListener(_refresh);
    ModuleAds.offer().then((o) {
      if (mounted) setState(() => _offer = o);
    });
  }

  @override
  void dispose() {
    ModuleAds.changes.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _buy() async {
    final user = context.read<UserAuthProvider>().loginUserData;
    if ((user.giftCoinsBalance ?? 0) < _offer.price) {
      await CoinCheckout.insufficient(context, _offer.price);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Sans pub pendant {d} jours', {'d': '${_offer.days}'})),
        content: Text(context.tr('Plus aucune pub dans Quiz, Étude et Contes pendant {d} jours, pour {p} pièces. Les pubs que tu choisis pour débloquer un contenu restent possibles.', {'d': '${_offer.days}', 'p': CoinCheckout.fmt(_offer.price)})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Annuler'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Payer'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ModuleAds.buy(user);
      if (!mounted) return;
      await CoinCheckout.refreshBalance(context);
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('C\'est fait : plus de pub dans Quiz, Étude et Contes.'))));
      }
    } on ModuleAdFreeException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.insufficient) {
        await CoinCheckout.refreshBalance(context);
        if (mounted) await CoinCheckout.insufficient(context, _offer.price);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr("Le paiement n'a pas pu être effectué. Tu n'as pas été débité."))));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Connexion impossible. Vérifie ta connexion.'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserAuthProvider>().loginUserData;
    final until = ModuleAds.endsAt(user);
    if (until == null && (!_offer.enabled || !AdConfig.isMobile || !AdConfig.current.enabled)) return const SizedBox.shrink();
    final conte = widget.style == ModuleAdFreeStyle.conte;
    final c = AppColors.of(context);
    final Color bg = conte ? ConteStyle.night2 : c.surface;
    final Color border = until != null ? (conte ? ConteStyle.green : c.primary) : (conte ? ConteStyle.gold.withOpacity(.7) : c.border);
    final Color fg = conte ? ConteStyle.parch : c.textPrimary;
    final Color sub = conte ? ConteStyle.parch2 : c.textSecondary;
    final Color accent = conte ? ConteStyle.gold2 : c.supportAccent;
    final TextStyle titleStyle = conte ? ConteStyle.body(17, color: fg, weight: FontWeight.w600) : TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 15);
    final TextStyle subStyle = conte ? ConteStyle.body(14.5, color: sub, style: FontStyle.italic) : TextStyle(color: sub, fontSize: 12.5, height: 1.3);
    String two(int n) => n.toString().padLeft(2, '0');
    return Padding(
      padding: widget.margin,
      child: GestureDetector(
        onTap: until != null || _busy ? null : _buy,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 1.3)),
          child: Row(children: [
            Icon(until != null ? Icons.check_circle_rounded : Icons.block_rounded, color: until != null ? (conte ? ConteStyle.green : c.primary) : accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(until != null ? context.tr('Sans pub jusqu\'au {d}', {'d': '${two(until.day)}/${two(until.month)}'}) : context.tr('Sans pub pendant {d} jours', {'d': '${_offer.days}'}), style: titleStyle),
                const SizedBox(height: 2),
                Text(
                  until != null ? context.tr('Quiz, Étude et Contes. Tu peux toujours choisir une pub pour débloquer.') : context.tr('Quiz, Étude et Contes. Les déblocages restent à ton choix.'),
                  style: subStyle,
                ),
              ]),
            ),
            if (until == null)
              _busy
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: accent))
                  : Text(context.tr('{a} pièces', {'a': CoinCheckout.fmt(_offer.price)}), style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}
