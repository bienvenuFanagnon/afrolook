import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../services/ad_config_service.dart';
import '../../services/coin_checkout.dart';
import '../../theme/app_colors.dart';
import '../../utils/platform_guard.dart';
import '../pub/ad_actions.dart';
import '../user/userPubs/user_create_advertisement_page.dart';
import 'defi_ui.dart';

const Color _orange = Color(0xFFFF9500);

/// Page à ouvrir quand on veut « booster » un post : pour un DÉFI, la publicité du DÉFI (le post reste un DÉFI, il n'est jamais
/// transformé en publicité) ; pour tout autre post, la publicité habituelle.
Widget boostPageFor(Post post) => post.type == PostType.DEFI.name ? DefiBoostPage(post: post) : UserCreateAdvertisementPage(existingPost: post);

class DefiBoost {
  DefiBoost._();

  /// Le créateur d'un DÉFI en cours, avec une image ou une vidéo à montrer dans la publicité.
  static bool canBoost(Post post, UserData me) {
    if (post.type != PostType.DEFI.name || post.defiConfig == null || isDefiOver(post)) return false;
    if (post.user_id != me.id && me.role != UserRole.ADM.name) return false;
    final t = post.dataType;
    return t == PostDataType.IMAGE.name || t == PostDataType.VIDEO.name;
  }
}

/// Publicité d'un DÉFI en cours : même circuit que les publicités Afrolook (durée au même tarif, pays, validation par l'équipe, diffusion
/// partagée avec les autres publicités), avec un bouton « Participer » qui ouvre le DÉFI dans l'application. Ce n'est pas la même chose que
/// les DÉFIS en cours qui reviennent gratuitement dans le fil : ici le créateur paie pour être vu par plus de monde.
class DefiBoostPage extends StatefulWidget {
  const DefiBoostPage({super.key, required this.post});
  final Post post;

  @override
  State<DefiBoostPage> createState() => _DefiBoostPageState();
}

class _DefiBoostPageState extends State<DefiBoostPage> {
  late final TextEditingController _text = TextEditingController(text: _initialText());
  List<AdDuration> _durations = AdConfigService.defaults;
  int? _weeks;
  bool _allCountries = true;
  final Set<String> _countries = {};
  bool _busy = false;

  String _initialText() {
    final d = (widget.post.description ?? '').trim();
    final base = d.isEmpty ? 'Un défi t’attend sur Afrolook : participe et tente de gagner la cagnotte !' : d;
    return base.length > 180 ? base.substring(0, 180) : base;
  }

  @override
  void initState() {
    super.initState();
    AdConfigService.getDurations().then((d) {
      if (mounted) setState(() => _durations = d);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _fmt(int fcfa) => kPayInCoins ? CoinCheckout.priceLabel(fcfa) : '$fcfa FCFA';

  void _say(String t, {bool error = true}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), backgroundColor: error ? Colors.red : null));

  String? _thumb() {
    final p = widget.post;
    if ((p.thumbnail ?? '').isNotEmpty) return p.thumbnail;
    final imgs = (p.images ?? const <String>[]).where((u) => u.isNotEmpty);
    return imgs.isEmpty ? null : imgs.first;
  }

  Future<void> _pickCountries() async {
    final all = AfricanCountry.everyCountry;
    final chosen = {..._countries};
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        var q = '';
        return StatefulBuilder(builder: (ctx, setM) {
          final c = AppColors.of(ctx);
          final list = all.where((x) => x.name.toLowerCase().contains(q) || x.code.toLowerCase().contains(q)).toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.8,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  onChanged: (v) => setM(() => q = v.trim().toLowerCase()),
                  decoration: InputDecoration(hintText: ctx.tr('Chercher un pays'), prefixIcon: const Icon(Icons.search)),
                ),
              ),
              Expanded(
                child: ListView(children: [
                  for (final x in list)
                    CheckboxListTile(
                      value: chosen.contains(x.code),
                      onChanged: (v) => setM(() => v == true ? chosen.add(x.code) : chosen.remove(x.code)),
                      title: Text('${x.flag}  ${x.name}', style: TextStyle(color: c.textPrimary)),
                      activeColor: _orange,
                    ),
                ]),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('Valider')))),
                ),
              ),
            ]),
          );
        });
      },
    );
    if (mounted) setState(() => _countries..clear()..addAll(chosen));
  }

  Future<void> _submit() async {
    if (_weeks == null) return _say(tr('Choisis la durée de la publicité'));
    if (!_allCountries && _countries.isEmpty) return _say(tr('Choisis au moins un pays'));
    if (_text.text.trim().isEmpty) return _say(tr('Écris un court texte pour la publicité'));
    final price = AdConfigService.toMap(_durations)[_weeks!] ?? 0;
    final me = context.read<UserAuthProvider>().loginUserData;
    final isAdmin = me.role == UserRole.ADM.name;
    if (!isAdmin) {
      final paid = await CoinCheckout.pay(context, kind: 'ad', priceFcfa: price.toDouble(), label: 'Publicité du défi', weeks: _weeks);
      if (!paid || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      final days = _weeks! * 7;
      final countries = _allCountries ? AfricanCountry.everyCountry.map((c) => c.code).toList() : _countries.toList();
      final db = FirebaseFirestore.instance;
      final adId = db.collection('Advertisements').doc().id;
      final owner = '${me.prenom ?? ''} ${me.nom ?? ''}'.trim().isNotEmpty ? '${me.prenom ?? ''} ${me.nom ?? ''}'.trim() : (me.pseudo ?? '');
      final ad = Advertisement(
        id: adId,
        postId: widget.post.id,
        actionType: 'defi',
        actionUrl: '${AdActions.defiScheme}${widget.post.id}',
        actionButtonText: 'Participer',
        durationDays: days,
        startDate: now,
        endDate: now + (days * 24 * 60 * 60 * 1000000),
        status: 'pending',
        isRenewable: true,
        renewalCount: 0,
        pricePaid: price,
        createdBy: me.id,
        createdAt: now,
        updatedAt: now,
        ownerType: 'challenge',
        ownerId: widget.post.id,
        ownerName: owner.isEmpty ? null : owner,
        ownerAvatar: (me.imageUrl ?? '').isEmpty ? null : me.imageUrl,
      );
      final json = ad.toJson()
        ..['boostType'] = 'defi'
        ..['availableCountries'] = countries
        ..['description'] = _text.text.trim();
      await db.collection('Advertisements').doc(adId).set(json);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('Demande envoyée')),
          content: Text(ctx.tr('La publicité de ton défi est en attente de validation par l’équipe Afrolook. Elle sera diffusée avec un bouton « Participer ».')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('OK')))],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('DefiBoostPage._submit : $e');
      if (mounted) _say(tr('Impossible d’envoyer la demande. Réessaie.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final cfg = widget.post.defiConfig;
    final thumb = _thumb();
    if (!DefiBoost.canBoost(widget.post, context.read<UserAuthProvider>().loginUserData)) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('Booster ce défi'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(context.tr('La publicité d’un défi est possible pour un défi en cours qui a une image ou une vidéo.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(context.tr('Booster ce défi'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(
          context.tr('Fais voir ton défi à plus de monde : il passera comme une publicité Afrolook, avec un bouton « Participer ».'),
          style: TextStyle(color: c.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _orange.withOpacity(0.5))),
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            if (thumb != null)
              ClipRRect(borderRadius: BorderRadius.circular(10), child: CachedNetworkImage(imageUrl: thumb, width: 72, height: 72, fit: BoxFit.cover))
            else
              const Icon(Icons.emoji_events_rounded, color: _orange, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🏆 ${cfg?.cagnottePieces ?? 0} ${context.tr('pièces en jeu')}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(context.tr('Bouton : Participer'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(context.tr('Texte de la publicité'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        TextField(controller: _text, maxLines: 3, maxLength: 180, decoration: const InputDecoration(border: OutlineInputBorder())),
        const SizedBox(height: 8),
        Text(context.tr('Durée'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in _durations)
            ChoiceChip(
              selected: _weeks == d.weeks,
              onSelected: (_) => setState(() => _weeks = d.weeks),
              label: Text('${d.label} · ${_fmt(d.price)}'),
              selectedColor: _orange.withOpacity(0.25),
            ),
        ]),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _allCountries,
          activeColor: _orange,
          onChanged: (v) => setState(() => _allCountries = v),
          title: Text(context.tr('Diffuser partout'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
          subtitle: Text(_allCountries ? context.tr('Tous les pays') : '${_countries.length} ${context.tr('pays choisis')}', style: TextStyle(color: c.textSecondary)),
        ),
        if (!_allCountries) OutlinedButton.icon(onPressed: _pickCountries, icon: const Icon(Icons.public), label: Text(context.tr('Choisir les pays'))),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _orange, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? context.tr('Envoi…') : context.tr('Payer et lancer la publicité')),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('Les votes et les vues d’un défi ne sont jamais monétisés. La publicité est validée par l’équipe Afrolook avant sa diffusion.'),
          style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4),
        ),
      ]),
    );
  }
}
