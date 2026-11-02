import 'package:afrotok/services/currency_service.dart';
import 'dart:io' show Platform;

import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/tr.dart';
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

  @override
  void initState() {
    super.initState();
    // le chargement attend que la page soit affichée : la langue de la personne (Localizations) n'est lisible qu'à ce moment-là
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  String _message(Object e) {
    if (e is ApiException) {
      switch (e.code) {
        case 'account_too_young':
          return tr('Les tâches s\'ouvrent quelques jours après l\'inscription. Reviens bientôt !');
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
      // lang : les instructions des tâches (écrites en anglais par nos partenaires) sont traduites par le serveur dans la langue de la personne
      final r = await ApiGateway.instance.client.get('/offerwall/torox/offers', query: {'platform': _platform, 'lang': Localizations.localeOf(context).languageCode});
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
      // Aucune pub ici : elle est passée avant la liste des tâches. 1) le serveur donne le lien de suivi ; 2) la tâche s'ouvre
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
                  Text(tr('Choisis une tâche : tes pièces arrivent après 30 jours.'), style: TextStyle(color: c.textSecondary, fontSize: 13)),
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

  /// Consignes COMPLÈTES de la tâche, avant de la commencer : ce qu'il faut faire, les détails, le gain et le délai de paiement.
  Future<void> _showInstructions(AppColors c, Map<String, dynamic> o) async {
    final action = '${o['action'] ?? ''}'.trim();
    final desc = '${o['description'] ?? ''}'.trim();
    final coins = (o['coins'] as num?)?.toInt() ?? 0;
    final icon = o['icon'] as String?;
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.background,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: icon == null ? Container(width: 56, height: 56, color: c.border, child: Icon(Icons.work_outline_rounded, color: c.textSecondary)) : CachedNetworkImage(imageUrl: icon, width: 56, height: 56, fit: BoxFit.cover, errorWidget: (_, __, ___) => Container(width: 56, height: 56, color: c.border)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${o['title']}', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.primary.withOpacity(0.35))),
                  child: Row(children: [
                    Icon(Icons.savings_rounded, color: c.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${tr('Tu gagnes {c} pièces (≈ {f} F)', {'c': _n.format(coins), 'f': _n.format((coins * 0.4).floor())})} · ≈ ${Money.usd(coins * 0.4)}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800))),
                  ]),
                ),
                if (action.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(tr('Ce que tu dois faire'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  SelectableText(action, style: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.45)),
                ],
                if (desc.isNotEmpty && desc != action) ...[
                  const SizedBox(height: 16),
                  Text(tr('Détails'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  SelectableText(desc, style: TextStyle(color: c.textSecondary, fontSize: 13.5, height: 1.45)),
                ],
                if (action.isEmpty && desc.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(tr("Le partenaire n'a pas donné de consignes : elles s'affichent sur la page de la tâche."), style: TextStyle(color: c.textSecondary))),
                const SizedBox(height: 16),
                Text(tr("Fais la tâche toi-même, en suivant les consignes jusqu'au bout. Tes pièces sont « en attente » 30 jours, puis versées si la tâche est validée."), style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.play_arrow_rounded), label: Text(tr('Commencer la tâche')))),
          ),
        ]),
      ),
    );
    if (go == true && mounted) _open(o);
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
          onTap: _opening ? null : () => _showInstructions(c, o),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(tr('Voir toutes les consignes'), style: TextStyle(color: c.primary, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: c.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text('+${_n.format((o['coins'] as num?)?.toInt() ?? 0)}', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 14)),
                ),
                // équivalent en FCFA (25 pièces = 10 F), arrondi vers le bas : on ne promet jamais plus que le gain réel
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 4),
                  child: Text('${tr('≈ {f} F', {'f': _n.format((((o['coins'] as num?)?.toInt() ?? 0) * 0.4).floor())})} · ≈ ${Money.usd(((o['coins'] as num?)?.toInt() ?? 0) * 0.4)}', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
