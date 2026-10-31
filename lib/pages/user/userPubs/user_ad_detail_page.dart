import 'package:afrotok/services/ad_config_service.dart';
import 'package:afrotok/services/api/boosts_api.dart';
import 'package:afrotok/services/api/compte_api.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'boost_widgets.dart';

/// Détail d'une de mes annonces (`GET /ads/account/ads/{id}`) : état, durée, vues et clics (visibles par toi seul), renouvellement payant
/// (`POST /ads/account/ads/{id}/renew`) et suppression (`DELETE`). En cas d'erreur : message + « Réessayer », jamais de repli.
class UserAdDetailPage extends StatefulWidget {
  final String advertisementId;
  const UserAdDetailPage({Key? key, required this.advertisementId}) : super(key: key);

  @override
  State<UserAdDetailPage> createState() => _UserAdDetailPageState();
}

class _UserAdDetailPageState extends State<UserAdDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _ad;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final a = await BoostsApi.get(widget.advertisementId);
      if (!mounted) return;
      setState(() {
        _ad = a;
        _error = a == null ? 'Publicité introuvable.' : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = BoostsApi.message(e);
        _loading = false;
      });
    }
  }

  String _date(dynamic iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _target(String? t) => switch (t) {
        'post' => 'Publication',
        'profile' => 'Profil',
        'canal' => 'Canal',
        'group' => 'Groupe',
        _ => '',
      };

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la publicité ?'),
        content: const Text('La publicité s\'arrête et disparaît de ta liste. Les pièces déjà payées ne sont pas remboursées. Ta publication reste publiée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await BoostsApi.delete(widget.advertisementId);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        BoostUi.showError(context, e, _delete, fallback: 'Suppression impossible. Réessaie.');
      }
    }
  }

  Future<void> _renew() async {
    final durations = await AdConfigService.getDurations();
    if (!mounted) return;
    final c = AppColors.of(context);
    final weeks = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text('Prolonger de…', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          for (final d in durations)
            ListTile(
              title: Text(d.label, style: TextStyle(color: c.textPrimary)),
              trailing: Text(CoinCheckout.coinsLabel(BoostUi.estimateCoins(durations, d.weeks)), style: TextStyle(color: c.textSecondary)),
              onTap: () => Navigator.pop(ctx, d.weeks),
            ),
        ]),
      ),
    );
    if (weeks == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final coins = await BoostUi.quote('ad_renew', weeks, durations);
      if (!mounted) return;
      final ok = await BoostUi.confirmPrice(context, title: 'Renouveler la publicité', coins: coins);
      if (!ok || !mounted) return;
      final updated = await BoostsApi.renew(widget.advertisementId, weeks);
      if (!mounted) return;
      await BoostUi.refreshBalance(context);
      if (!mounted) return;
      setState(() => _ad = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Publicité renouvelée.')));
    } catch (e) {
      if (mounted) BoostUi.showError(context, e, _renew, fallback: 'Renouvellement impossible. Réessaie.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _stat(AppColors c, String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
          child: Column(children: [
            Text(value, style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = _ad;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Ma publicité'), backgroundColor: c.surface, foregroundColor: c.textPrimary, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || a == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error ?? '', textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
                      const SizedBox(height: 14),
                      ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                    ]),
                  ),
                )
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final url in CompteApi.adImages(a))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)),
                    ),
                  Text('${a['title'] ?? ''}', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('${a['text'] ?? ''}', style: TextStyle(color: c.textSecondary, height: 1.4)),
                  const SizedBox(height: 14),
                  Row(children: [
                    _stat(c, 'Vues', '${(a['views'] as num?)?.toInt() ?? 0}'),
                    const SizedBox(width: 10),
                    _stat(c, 'Clics', '${(a['clicks'] as num?)?.toInt() ?? 0}'),
                    const SizedBox(width: 10),
                    _stat(c, 'Renouvellements', '${(a['renewal_count'] as num?)?.toInt() ?? 0}'),
                  ]),
                  const SizedBox(height: 14),
                  Text('Statut : ${CompteApi.statusLabel(a['status'] as String?)}', style: TextStyle(color: c.textPrimary)),
                  if ((a['status'] == 'rejected') && (a['reject_reason'] ?? '').toString().isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text('Motif : ${a['reject_reason']}', style: TextStyle(color: c.danger))),
                  if (_target(a['target'] as String?).isNotEmpty) Text('Cible : ${_target(a['target'] as String?)}', style: TextStyle(color: c.textSecondary)),
                  if (a['ends_at'] != null) Text('Jusqu\'au ${_date(a['ends_at'])}', style: TextStyle(color: c.textSecondary)),
                  if ((a['action_url'] ?? '').toString().isNotEmpty) Text('Lien : ${a['action_url']}', style: TextStyle(color: c.textSecondary)),
                  const SizedBox(height: 20),
                  if (a['paid'] == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _renew,
                        icon: const Icon(Icons.autorenew),
                        label: const Text('Renouveler'),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(_busy ? 'Un instant…' : 'Supprimer'),
                  ),
                ]),
    );
  }
}
