import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/quiz/quiz_service.dart';
import '../../services/quiz/quiz_sound.dart';
import '../../theme/app_colors.dart';
import 'widgets/hawk_mascot.dart';
import 'widgets/quiz_widgets.dart';

class _ShopItem {
  const _ShopItem(this.id, this.slot, this.name, this.desc, this.price);
  final String id;
  final String? slot; // null = bouclier
  final String name, desc;
  final int price;
}

const List<_ShopItem> _catalog = [
  _ShopItem('shield', null, 'Bouclier de flamme', 'Protège ta série si tu rates un jour (3 au maximum).', 300),
  _ShopItem('acc_glasses', 'accessory', 'Lunettes de l\'épervier', 'Un air de grand savant pour ta mascotte.', 400),
  _ShopItem('acc_cap', 'accessory', 'Casquette de l\'épervier', 'Aux couleurs d\'Afrolook.', 500),
  _ShopItem('acc_crown', 'accessory', 'Couronne de l\'épervier', 'Pour le roi ou la reine du quiz.', 900),
  _ShopItem('frame_green', 'frame', 'Cadre vert', 'Un cadre vert autour de ta photo dans le classement.', 500),
  _ShopItem('frame_gold', 'frame', 'Cadre doré', 'Un cadre doré autour de ta photo dans le classement.', 800),
  _ShopItem('title_scholar', 'title', 'Titre « Érudit »', 'Affiché sous ton nom dans le classement.', 700),
  _ShopItem('title_lion', 'title', 'Titre « Lion du savoir »', 'Affiché sous ton nom dans le classement.', 1000),
];

/// Boutique de points : cadres, titres, accessoires de l'épervier, bouclier de flamme.
/// Les points se dépensent ici et ne s'échangent jamais contre de l'argent.
class QuizShopPage extends StatefulWidget {
  const QuizShopPage({super.key});

  @override
  State<QuizShopPage> createState() => _QuizShopPageState();
}

class _QuizShopPageState extends State<QuizShopPage> {
  String? _busy;

  @override
  void initState() {
    super.initState();
    QuizService.instance.refresh().catchError((_) => const QuizState());
  }

  int _price(_ShopItem it) {
    final o = QuizService.instance.config.shop[it.id];
    final p = o?['price'];
    return p is num ? p.toInt() : it.price;
  }

  bool _enabled(_ShopItem it) => QuizService.instance.config.shop[it.id]?['enabled'] != false;

  Future<void> _buy(_ShopItem it, QuizState s) async {
    final c = AppColors.of(context);
    final price = _price(it);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(ctx.tr(it.name), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900)),
        content: Text(ctx.tr('Dépenser {n} points ?', {'n': price}), style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Annuler'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Acheter'), style: TextStyle(color: c.primary, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = it.id);
    try {
      await QuizService.instance.buy(it.id);
      QuizSound.fx(QuizSfx.win);
      if (mounted) quizToast(context, context.tr('Acheté !'));
    } on QuizException catch (e) {
      if (!mounted) return;
      QuizSound.fx(QuizSfx.bad);
      final code = e.code;
      quizToast(
        context,
        code.contains('NOT_ENOUGH')
            ? context.tr("Tu n'as pas assez de points.")
            : code.contains('SHIELD_MAX')
                ? context.tr('Tu as déjà le maximum de boucliers.')
                : code.contains('ALREADY')
                    ? context.tr('Tu possèdes déjà cet objet.')
                    : context.tr('Achat impossible pour le moment.'),
        error: true,
      );
    } catch (_) {
      if (mounted) quizToast(context, context.tr('Connexion impossible. Vérifie ta connexion.'), error: true);
    }
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _equip(_ShopItem it, bool equipped) async {
    setState(() => _busy = it.id);
    try {
      await QuizService.instance.equip(it.slot!, equipped ? null : it.id);
      QuizSound.fx(QuizSfx.up);
    } catch (_) {
      if (mounted) quizToast(context, context.tr('Une erreur est survenue, réessaie.'), error: true);
    }
    if (mounted) setState(() => _busy = null);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(context.tr('Boutique'), style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
      ),
      body: ValueListenableBuilder<QuizState?>(
        valueListenable: QuizService.instance.state,
        builder: (_, s0, __) {
          final s = s0 ?? const QuizState();
          final items = _catalog.where(_enabled).toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c.accent.withOpacity(0.28), c.surface]),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: c.accent, width: 1.5),
                ),
                child: Row(children: [
                  HawkMascot(size: 80, accessory: s.equipped['accessory']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.star_rounded, color: c.accent, size: 26),
                        const SizedBox(width: 4),
                        Text('${s.points}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c.textPrimary)),
                      ]),
                      Text(context.tr('points à dépenser'), style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('Les points ne valent pas d\'argent : ils servent à te personnaliser.'),
                        style: TextStyle(color: c.textSecondary, fontSize: 11.5),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              for (final it in items) _tile(c, it, s),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(AppColors c, _ShopItem it, QuizState s) {
    final isShield = it.slot == null;
    final owned = !isShield && (s.inventory[it.id] ?? false);
    final equipped = !isShield && s.equipped[it.slot] == it.id;
    final price = _price(it);
    final can = s.points >= price;
    final busy = _busy == it.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: equipped ? c.primary : c.border, width: 1.5),
      ),
      child: Row(children: [
        SizedBox(width: 70, height: 70, child: Center(child: _preview(c, it, s))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr(it.name), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: c.textPrimary)),
            const SizedBox(height: 2),
            Text(context.tr(it.desc), style: TextStyle(color: c.textSecondary, fontSize: 12.5, height: 1.3)),
            if (isShield)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(context.tr('Tu en as {n}', {'n': s.shields}), style: TextStyle(color: c.warning, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 96,
          child: owned
              ? QuizChunkyButton(
                  label: equipped ? context.tr('Retirer') : context.tr('Équiper'),
                  color: equipped ? c.surfaceVariant : c.primary,
                  textColor: equipped ? c.textPrimary : c.onPrimary,
                  loading: busy,
                  onPressed: () => _equip(it, equipped),
                )
              : QuizChunkyButton(
                  label: '$price',
                  icon: Icons.star_rounded,
                  color: can ? c.accent : c.surfaceVariant,
                  textColor: can ? c.onAccent : c.textSecondary,
                  loading: busy,
                  onPressed: can ? () => _buy(it, s) : () => quizToast(context, context.tr("Tu n'as pas assez de points."), error: true),
                ),
        ),
      ]),
    );
  }

  Widget _preview(AppColors c, _ShopItem it, QuizState s) {
    switch (it.slot) {
      case 'accessory':
        return HawkMascot(size: 70, accessory: it.id);
      case 'frame':
        final ring = it.id == 'frame_gold' ? c.accent : c.primary;
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: 4)),
          child: CircleAvatar(radius: 24, backgroundColor: c.surfaceVariant, child: Icon(Icons.person_rounded, color: c.textSecondary)),
        );
      case 'title':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: c.accent.withOpacity(0.16), borderRadius: BorderRadius.circular(10)),
          child: Icon(it.id == 'title_lion' ? Icons.pets_rounded : Icons.school_rounded, color: c.supportAccent, size: 30),
        );
      default:
        return Icon(Icons.local_fire_department_rounded, color: c.warning, size: 42);
    }
  }
}
