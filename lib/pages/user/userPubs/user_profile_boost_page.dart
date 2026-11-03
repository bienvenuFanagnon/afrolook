import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/services/ad_config_service.dart';
import 'package:afrotok/services/api/boosts_api.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'boost_widgets.dart';

/// Boost payant d'un profil, d'un canal ou d'un groupe de chat (`POST /ads/boosts`, cible `profile`, `canal` ou `group`).
/// Le débit en pièces et la création de l'annonce se font dans UNE SEULE opération côté serveur ; l'annonce attend ensuite la validation
/// de l'équipe. Le prix est donné par le serveur ; en cas d'erreur : message en français + « Réessayer », jamais de repli.
class UserProfileBoostPage extends StatefulWidget {
  /// Si null → boost du profil utilisateur.
  final Canal? canal;

  /// Si non-null → boost du groupe de chat spécifié. Attendu : {'id': String, 'name': String, 'image_url': String?, 'member_count': int?}
  final Map<String, dynamic>? group;

  const UserProfileBoostPage({Key? key, this.canal, this.group}) : super(key: key);

  @override
  State<UserProfileBoostPage> createState() => _UserProfileBoostPageState();
}

class _UserProfileBoostPageState extends State<UserProfileBoostPage> {
  static const Color _gold = Color(0xFFFFD700);

  final _desc = TextEditingController();
  List<AdDuration> _durations = AdConfigService.defaults;
  int? _weeks;
  bool _allCountries = true;
  Set<String> _countries = {};
  bool _busy = false;

  bool get _isCanal => widget.canal != null;
  bool get _isGroup => widget.group != null;
  String get _target => _isGroup ? 'group' : (_isCanal ? 'canal' : 'profile');
  String get _entityLabel => _isGroup ? 'groupe' : (_isCanal ? 'canal' : 'profil');

  @override
  void initState() {
    super.initState();
    AdConfigService.getDurations().then((d) {
      if (mounted) setState(() => _durations = d);
    });
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  String _targetId(UserData me) => _isGroup ? '${widget.group!['id']}' : (_isCanal ? (widget.canal!.id ?? '') : (me.id ?? ''));

  String _entityName(UserData me) {
    if (_isGroup) return '${widget.group!['name'] ?? 'Groupe'}';
    if (_isCanal) return '#${widget.canal!.titre ?? 'Canal'}';
    final full = '${me.prenom ?? ''} ${me.nom ?? ''}'.trim();
    return full.isNotEmpty ? full : (me.pseudo ?? 'Mon profil');
  }

  String? _entityAvatar(UserData me) => _isGroup ? widget.group!['image_url'] as String? : (_isCanal ? widget.canal!.urlImage : me.imageUrl);

  /// Texte du bouton de la publicité.
  String get _actionText => _isGroup ? 'Rejoindre' : (_isCanal ? "S'abonner" : 'Suivre');

  void _say(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t), backgroundColor: Colors.red));

  Future<void> _submit() async {
    final me = context.read<UserAuthProvider>().loginUserData;
    if (_weeks == null) return _say('Choisis la durée');
    if (_desc.text.trim().isEmpty) return _say('La description est obligatoire');
    if (!_allCountries && _countries.isEmpty) return _say('Choisis au moins un pays');
    final id = _targetId(me);
    if (id.isEmpty) return _say('Impossible de retrouver ce $_entityLabel. Réessaie.');
    setState(() => _busy = true);
    try {
      final coins = await BoostUi.quote('profile_boost', _weeks!, _durations);
      if (!mounted) return;
      final ok = await BoostUi.confirmPrice(context, title: 'Booster ${_isGroup ? 'le groupe' : _isCanal ? 'le canal' : 'mon profil'}', coins: coins);
      if (!ok || !mounted) return;
      // Une seule opération côté serveur : débit en pièces ET annonce en attente de validation par l'équipe
      await BoostsApi.create(
        target: _target,
        targetId: id,
        weeks: _weeks!,
        countries: _allCountries ? const ['ALL'] : _countries.toList(),
        actionText: _actionText,
        description: _desc.text,
        title: _entityName(me),
      );
      if (!mounted) return;
      await BoostUi.refreshBalance(context);
      if (!mounted) return;
      await _showDone();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('UserProfileBoostPage._submit : $e');
      if (mounted) BoostUi.showError(context, e, _submit);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showDone() {
    final c = AppColors.of(context);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Row(children: [
          const Icon(Icons.check_circle, color: _gold),
          const SizedBox(width: 8),
          Expanded(child: Text('Demande envoyée', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold))),
        ]),
        content: Text(
          'Ton boost ${_isGroup ? 'de groupe' : _isCanal ? 'de canal' : 'de profil'} est en attente de validation par l\'équipe. '
          'Tu peux suivre son état dans « Mes publicités ».',
          style: TextStyle(color: c.textSecondary, height: 1.4),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final me = context.watch<UserAuthProvider>().loginUserData;
    final avatar = _entityAvatar(me);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: Text('Booster ${_isGroup ? 'le groupe' : _isCanal ? 'le canal' : 'mon profil'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _gold.withOpacity(0.5))),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                width: 56,
                height: 56,
                child: (avatar ?? '').isEmpty ? Container(color: c.surfaceVariant, child: Icon(Icons.person, color: c.textSecondary)) : CachedNetworkImage(imageUrl: avatar!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_entityName(me), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
        ),
        const SizedBox(height: 12),
        Text(
          'Ton $_entityLabel passera comme une publicité, avec un bouton « $_actionText ». L\'équipe la valide avant sa diffusion.',
          style: TextStyle(color: c.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        Text('Description de la publicité', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        TextField(controller: _desc, maxLines: 3, maxLength: 220, decoration: InputDecoration(border: const OutlineInputBorder(), hintText: 'Présente ton $_entityLabel en quelques mots')),
        const SizedBox(height: 8),
        Text('Durée', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        BoostDurationChips(durations: _durations, selected: _weeks, onSelected: (w) => setState(() => _weeks = w), color: _gold),
        const SizedBox(height: 14),
        BoostCountriesField(
          allCountries: _allCountries,
          countries: _countries,
          onAllChanged: (v) => setState(() => _allCountries = v),
          onCountriesChanged: (s) => setState(() => _countries = s),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Text('Payer et lancer le boost', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}
