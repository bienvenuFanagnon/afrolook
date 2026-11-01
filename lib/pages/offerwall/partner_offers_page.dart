import 'dart:io' show Platform;

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ads/task_ads.dart';
import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';

/// Galerie des tâches de nos partenaires : NOTRE écran (liste lue par le serveur). Avant CHAQUE offre ouverte, une pub plein écran passe d'abord
/// (Appodeal, puis AdMob en renfort), puis la tâche s'ouvre. Les pièces affichées sont celles du serveur ; le lien de suivi n'est donné qu'au toucher.
class PartnerOffersPage extends StatefulWidget {
  const PartnerOffersPage({super.key});

  @override
  State<PartnerOffersPage> createState() => _PartnerOffersPageState();
}

class _PartnerOffersPageState extends State<PartnerOffersPage> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  List<Map<String, dynamic>> _offers = const [];
  bool _loading = true;
  bool _opening = false;
  String? _error;

  String get _platform => (!kIsWeb && Platform.isIOS) ? 'ios' : 'android';
  UserAuthProvider get _auth => Provider.of<UserAuthProvider>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TaskAds.warmUp(_auth.loginUserData);   // la pub est prête quand la personne touche une offre
    });
  }

  String _message(Object e) {
    if (e is ApiException) {
      switch (e.code) {
        case 'account_too_young':
          return tr('Les tâches seront disponibles dans quelques jours.');
        case 'email_unverified':
          return tr('Confirme ton e-mail pour utiliser cette fonction.');
        case 'account_inactive':
          return tr('Compte non éligible.');
        case 'too_many_clicks':
          return tr('Trop de tâches ouvertes aujourd\'hui. Reviens demain.');
        case 'offer_not_found':
          return tr('Cette tâche n\'est plus disponible.');
        case 'network':
          return tr('Pas de connexion.');
      }
    }
    return tr('Impossible de charger les tâches pour le moment. Réessaie plus tard.');
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ApiGateway.instance.client.get('/offerwall/torox/offers', query: {'platform': _platform});
      final rows = ((r is Map ? r['data'] : null) as List? ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      if (!mounted) return;
      setState(() { _offers = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = _message(e); });
    }
  }

  Future<void> _open(Map<String, dynamic> offer) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      // 1) La pub d'abord (Appodeal puis AdMob), jamais bloquante ; 2) le serveur donne le lien de suivi ; 3) la tâche s'ouvre
      await TaskAds.beforeOffer(_auth.loginUserData);
      final r = Map<String, dynamic>.from(ApiClient.data(await ApiGateway.instance.client.post('/offerwall/torox/offers/${offer['id']}/click', body: {'platform': _platform})) as Map);
      final uri = Uri.tryParse('${r['url']}');
      if (uri == null || uri.scheme != 'https') throw StateError('adresse refusée');
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) setState(() => _error = tr('Impossible d\'ouvrir les tâches pour le moment. Réessaie plus tard.'));
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(tr('Tâches de nos partenaires'))),
      body: RefreshIndicator(
        color: c.primary,
        onRefresh: _load,
        child: _loading
            ? ListView(children: [SizedBox(height: 240, child: Center(child: CircularProgressIndicator(color: c.primary)))])
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Text(tr('Choisis une tâche, termine-la en suivant ses consignes, et tes pièces arrivent « en attente » (versées après 30 jours).'),
                      style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 4),
                  Text(tr('Une publicité s\'ouvre avant chaque tâche.'), style: TextStyle(color: c.textSecondary.withOpacity(0.8), fontSize: 11.5)),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!, style: TextStyle(color: c.warning, fontWeight: FontWeight.w700, fontSize: 13)),
                    TextButton(onPressed: _load, child: Text(tr('Réessayer'))),
                  ],
                  const SizedBox(height: 10),
                  if (_offers.isEmpty && _error == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text(tr('Aucune tâche disponible pour le moment. Reviens un peu plus tard.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))),
                    ),
                  for (final o in _offers) _card(c, o),
                ],
              ),
      ),
    );
  }

  Widget _card(AppColors c, Map<String, dynamic> o) {
    final icon = o['icon'] as String?;
    final desc = '${o['action'] ?? ''}'.isNotEmpty ? '${o['action']}' : '${o['description'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _opening ? null : () => _open(o),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: icon == null
                    ? Container(width: 52, height: 52, color: c.border, child: Icon(Icons.work_outline_rounded, color: c.textSecondary))
                    : CachedNetworkImage(imageUrl: icon, width: 52, height: 52, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(width: 52, height: 52, color: c.border)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${o['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.3)),
                  ],
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: c.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text('+${_n.format((o['coins'] as num?)?.toInt() ?? 0)}', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
