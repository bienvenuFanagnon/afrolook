import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../layout/centered_content.dart';
import '../../theme/app_colors.dart';

/// Régie Afrolook Ads : validation des profils des annonceurs (marque, contact, logo), des profils de diffuseurs et de leurs sites ou applications.
/// Réservé aux administrateurs ; tout passe par les fonctions du serveur (adsAdv… et adsPub…, voir docs/ADS_EDITEURS_PROPOSITION.md).
/// Un diffuseur propose des sites et applications EN LIGNE ; chacun est accepté ou refusé séparément et reçoit son identifiant publicitaire (ap_…).
/// L'audience retenue de chaque site validé s'ajoute aux 50 000 de nos plateformes pour l'estimation affichée aux annonceurs.
class AdsRegieAdminPage extends StatefulWidget {
  const AdsRegieAdminPage({super.key});

  @override
  State<AdsRegieAdminPage> createState() => _AdsRegieAdminPageState();
}

class _AdsRegieAdminPageState extends State<AdsRegieAdminPage> {
  bool _loading = true;
  String? _error;
  String _filter = 'pending';
  List<Map<String, dynamic>> _logos = [];
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _props = [];
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _sharers = []; // partageurs « Partage et gagne » (utilisateurs de l'application)
  List<Map<String, dynamic>> _camps = []; // campagnes Partage des annonceurs

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    final res = await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable(name).call(data ?? <String, dynamic>{});
    return Map<String, dynamic>.from(res.data as Map);
  }

  String _err(Object e) => e is FirebaseFunctionsException ? (e.message ?? e.code) : e.toString();

  List<Map<String, dynamic>> _list(Object? v) => (v as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final logoStatus = switch (_filter) { 'all' => 'all', 'active' => 'approved', 'refused' => 'rejected', _ => 'pending' };
      final campStatus = switch (_filter) { 'all' => 'all', 'active' => 'active', 'refused' => 'refused', 'suspended' => 'paused', _ => 'pending' };
      final r = await Future.wait([
        _filter == 'suspended' ? Future.value(<String, dynamic>{'items': <dynamic>[]}) : _call('adsAdvAdminList', {'status': logoStatus}),
        _call('adsPubAdminList', {'status': _filter}),
        _call('adsPubAdminList', {'alerts': true, 'status': 'open'}).catchError((_) => <String, dynamic>{'alerts': <dynamic>[]}),
        _call('adsPubAdminList', {'sharers': true, 'status': _filter}).catchError((_) => <String, dynamic>{'sharers': <dynamic>[]}),
        _call('adsPubAdminList', {'campaigns': true, 'status': campStatus}).catchError((_) => <String, dynamic>{'campaigns': <dynamic>[]}),
      ]);
      if (!mounted) return;
      setState(() {
        _logos = _list(r[0]['items']);
        _profiles = _list(r[1]['profiles']);
        _props = _list(r[1]['properties']);
        _alerts = _list(r[2]['alerts']);
        _sharers = _list(r[3]['sharers']);
        _camps = _list(r[4]['campaigns']);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = _err(e); _loading = false; });
    }
  }

  void _toast(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }

  /// Demande un motif (obligatoire pour un refus ou une suspension) puis envoie la décision.
  Future<String?> _askReason(String title, {String label = 'Motif (envoyé par e-mail)'}) async {
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctl, maxLength: 300, maxLines: 3, decoration: InputDecoration(labelText: label)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer'))],
      ),
    );
    final t = ctl.text.trim();
    if (ok != true) return null;
    if (t.length < 5) { _toast('Le motif doit faire 5 caractères au moins.'); return null; }
    return t;
  }

  Future<void> _logoDecision(Map<String, dynamic> p, bool approve) async {
    String? reason;
    if (!approve) { reason = await _askReason('Refuser le profil'); if (reason == null) return; }
    try {
      await _call('adsAdvAdminReview', {'uid': p['uid'], 'decision': approve ? 'approve' : 'reject', if (reason != null) 'reason': reason});
      _toast(approve ? 'Profil validé' : 'Profil refusé');
      _load();
    } catch (e) { _toast(_err(e)); }
  }

  /// Alerte de la surveillance : vérifiée (rien d'anormal), bloquer les paiements de la plateforme, ou lever le blocage.
  Future<void> _alertDecision(Map<String, dynamic> a, String decision) async {
    String? reason;
    if (decision == 'hold') { reason = await _askReason('Bloquer les paiements', label: 'Pourquoi bloquer ? (gardé dans le journal)'); if (reason == null) return; }
    try {
      await _call('adsPubAdminReview', {'target': 'alert', 'id': a['id'], 'decision': decision, if (reason != null) 'reason': reason});
      _toast('Décision enregistrée');
      _load();
    } catch (e) { _toast(_err(e)); }
  }

  Future<void> _profileDecision(Map<String, dynamic> p, String decision) async {
    String? reason;
    if (decision == 'refuse' || decision == 'suspend') { reason = await _askReason(decision == 'refuse' ? 'Refuser le profil' : 'Suspendre le profil'); if (reason == null) return; }
    try {
      await _call('adsPubAdminReview', {'target': 'profile', 'id': p['uid'], 'decision': decision, if (reason != null) 'reason': reason});
      _toast('Décision enregistrée');
      _load();
    } catch (e) { _toast(_err(e)); }
  }

  Future<void> _propDecision(Map<String, dynamic> p, String decision) async {
    String? reason;
    int? counted;
    if (decision == 'refuse' || decision == 'suspend') {
      reason = await _askReason(decision == 'refuse' ? 'Refuser ce site ou cette application' : 'Suspendre la diffusion');
      if (reason == null) return;
    } else if (decision == 'approve') {
      // l'administrateur fixe l'audience retenue (jamais plus que la déclarée) : c'est elle qui s'ajoute aux 50 000
      final declared = (p['audienceMonthly'] as num?)?.toInt() ?? 0;
      final ctl = TextEditingController(text: '$declared');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Valider ce site ou cette application'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Audience déclarée : $declared personnes par mois.'),
            const SizedBox(height: 10),
            TextField(controller: ctl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Audience retenue (ajoutée aux 50 000)')),
            const SizedBox(height: 8),
            Text(p['verified'] == true ? 'Propriété du site vérifiée ✓' : 'Propriété non vérifiée (facultatif).', style: const TextStyle(fontSize: 12)),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Valider'))],
        ),
      );
      if (ok != true) return;
      counted = int.tryParse(ctl.text.trim());
    }
    try {
      await _call('adsPubAdminReview', {'target': 'property', 'id': p['id'], 'decision': decision, if (reason != null) 'reason': reason, if (counted != null) 'audienceCounted': counted});
      _toast('Décision enregistrée');
      _load();
    } catch (e) {
      final m = _err(e);
      _toast(m.contains('profil_non_valide') ? 'Valide d\'abord le profil du diffuseur.' : m);
    }
  }

  /// Partageur : valider (avec l'audience retenue, jamais plus que la déclarée), refuser, suspendre, lever un blocage, ou fraude confirmée (gains retirés).
  Future<void> _sharerDecision(Map<String, dynamic> p, String decision) async {
    String? reason;
    int? retained;
    if (decision == 'refuse' || decision == 'suspend' || decision == 'fraud') {
      reason = await _askReason(switch (decision) { 'refuse' => 'Refuser ce profil', 'suspend' => 'Suspendre ce profil', _ => 'Fraude confirmée : retirer les gains' },
          label: decision == 'fraud' ? 'Motif (gardé dans le journal)' : 'Motif (envoyé par e-mail)');
      if (reason == null) return;
    } else if (decision == 'approve' || decision == 'reactivate') {
      final declared = (p['declared'] as num?)?.toInt() ?? 0;
      final ctl = TextEditingController(text: '$declared');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(decision == 'approve' ? 'Valider ce partageur' : 'Réactiver ce partageur'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Audience déclarée : $declared personnes.'),
            const SizedBox(height: 10),
            TextField(controller: ctl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Audience retenue (au plus la déclarée)')),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Valider'))],
        ),
      );
      if (ok != true) return;
      retained = int.tryParse(ctl.text.trim());
    }
    try {
      await _call('adsPubAdminReview', {'target': 'sharer', 'id': p['uid'], 'decision': decision, if (reason != null) 'reason': reason, if (retained != null) 'audienceRetained': retained});
      _toast('Décision enregistrée');
      _load();
    } catch (e) { _toast(_err(e)); }
  }

  /// Campagne Partage : valider (paiement reçu), refuser, mettre en pause, reprendre ou terminer.
  Future<void> _campDecision(Map<String, dynamic> p, String decision) async {
    String? reason;
    if (decision == 'refuse' || decision == 'pause' || decision == 'end') {
      reason = await _askReason(switch (decision) { 'refuse' => 'Refuser cette campagne', 'pause' => 'Mettre la campagne en pause', _ => 'Terminer la campagne' },
          label: decision == 'refuse' ? 'Motif (envoyé par e-mail)' : 'Motif (gardé dans le journal)');
      if (reason == null) return;
    }
    try {
      await _call('adsPubAdminReview', {'target': 'campaign', 'id': p['id'], 'decision': decision, if (reason != null) 'reason': reason});
      _toast('Décision enregistrée');
      _load();
    } catch (e) { _toast(_err(e)); }
  }

  Widget _card(AppColors c, {required List<Widget> children}) => Card(
        color: c.surface,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
      );

  Widget _empty(AppColors c, String text) => Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(text, style: TextStyle(color: c.textSecondary), textAlign: TextAlign.center)));

  Widget _kv(AppColors c, String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 118, child: Text(k, style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
          Expanded(child: Text(v, style: TextStyle(color: c.textPrimary, fontSize: 13.5))),
        ]),
      );

  Widget _link(AppColors c, String label, String url) => url.isEmpty
      ? const SizedBox.shrink()
      : InkWell(
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(label, style: TextStyle(color: c.info, decoration: TextDecoration.underline, fontSize: 13))),
        );

  Widget _buttons(AppColors c, {required List<(String, VoidCallback, Color?)> items}) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Wrap(spacing: 8, runSpacing: 6, children: [
          for (final (label, fn, color) in items)
            color == null ? OutlinedButton(onPressed: fn, child: Text(label)) : FilledButton(style: FilledButton.styleFrom(backgroundColor: color), onPressed: fn, child: Text(label)),
        ]),
      );

  Widget _logosTab(AppColors c) {
    if (_logos.isEmpty) return _empty(c, 'Aucun annonceur dans cette liste.');
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final p in _logos)
        _card(c, children: [
          Row(children: [
            Container(
              width: 84, height: 84, decoration: BoxDecoration(color: c.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
              child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network('${p['logoUrl']}', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['brandName']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${p['sector']} · ${p['city']}, ${p['country']}', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              Text('${p['email'] ?? ''}', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              _link(c, 'Voir le logo en grand', '${p['logoUrl']}'),
            ])),
          ]),
          _kv(c, "Ce qu'ils font", '${p['about'] ?? ''}'),
          _kv(c, 'Contact', '${p['whatsapp'] ?? ''} · ${p['email'] ?? ''}'),
          _kv(c, 'Annonces', '${(p['stats'] as Map?)?['ads'] ?? 0} (dont ${(p['stats'] as Map?)?['active'] ?? 0} en ligne) · ${(p['stats'] as Map?)?['views'] ?? 0} vues · ${(p['stats'] as Map?)?['clicks'] ?? 0} clics'),
          _link(c, 'Site : ${p['website']}', '${p['website'] ?? ''}'),
          if ('${p['logoReason'] ?? ''}'.isNotEmpty) _kv(c, 'Motif du refus', '${p['logoReason']}'),
          _kv(c, 'Profil', switch ('${p['logoStatus']}') { 'approved' => 'Validé', 'rejected' => 'Refusé', _ => 'En validation' }),
          _kv(c, 'Accord partenaire', p['partnerConsent'] == true ? 'Oui (affichage autorisé)' : 'Non'),
          _buttons(c, items: [
            if (p['logoStatus'] != 'approved') ('Valider le profil', () => _logoDecision(p, true), c.primary),
            if (p['logoStatus'] != 'rejected') ('Refuser le profil', () => _logoDecision(p, false), null),
          ]),
        ]),
    ]);
  }

  Widget _profilesTab(AppColors c) {
    if (_profiles.isEmpty) return _empty(c, 'Aucun profil de diffuseur dans cette liste.');
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final p in _profiles)
        _card(c, children: [
          Text('${p['name']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
          _kv(c, 'Type', p['type'] == 'company' ? 'Entreprise' : 'Particulier'),
          _kv(c, 'Pays, ville', '${p['country']}, ${p['city']}'),
          _kv(c, 'WhatsApp', '${p['phone']}'),
          _kv(c, 'E-mail', '${p['email'] ?? ''}'),
          _link(c, 'Site : ${p['website']}', '${p['website'] ?? ''}'),
          _kv(c, 'Présentation', '${p['about']}'),
          if ('${p['reason'] ?? ''}'.isNotEmpty) _kv(c, 'Motif', '${p['reason']}'),
          _buttons(c, items: [
            if (p['status'] == 'pending' || p['status'] == 'refused') ('Valider le profil', () => _profileDecision(p, 'approve'), c.primary),
            if (p['status'] == 'suspended') ('Réactiver', () => _profileDecision(p, 'reactivate'), c.primary),
            if (p['status'] == 'pending') ('Refuser', () => _profileDecision(p, 'refuse'), null),
            if (p['status'] == 'active') ('Suspendre', () => _profileDecision(p, 'suspend'), null),
          ]),
        ]),
    ]);
  }

  /// Audience réellement mesurée par Afrolook (30 et 60 jours), comparée à la déclarée.
  String _measured(Object? m) {
    if (m is! Map) return 'pas encore de mesure';
    const gap = {'no_data': 'pas encore comparable', 'conform': 'conforme', 'below': 'en dessous', 'far_below': 'TRÈS EN DESSOUS de la déclarée', 'above': 'au-dessus'};
    return '${m['u30']} sur 30 j · ${m['u60']} sur 60 j · ${m['daysWithData']} jours de mesure · ${gap['${m['status']}'] ?? ''}';
  }

  String _alertTitle(Map<String, dynamic> a) {
    final ad = '${a['adId'] ?? ''}';
    final name = '${a['pubName'] ?? a['pub']}';
    return ad.isEmpty ? name : '$name · annonce ${ad.length > 8 ? ad.substring(0, 8) : ad}';
  }

  Widget _alertsTab(AppColors c) {
    if (_alerts.isEmpty) return _empty(c, 'Aucune alerte à vérifier. La surveillance contrôle les plateformes toutes les heures.');
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final a in _alerts)
        _card(c, children: [
          Row(children: [
            Text(a['severity'] == 'high' ? '🚨' : '⚠️', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(_alertTitle(a), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          _kv(c, 'Gravité', a['severity'] == 'high' ? 'Haute' : 'Moyenne'),
          _kv(c, 'Détecté', '${a['message']}'),
          _kv(c, 'Journée', '${a['day']}'),
          if (a['autoHold'] == true) _kv(c, 'Blocage', 'Paiements bloqués automatiquement (la diffusion continue)'),
          _buttons(c, items: [
            ('Vérifiée : rien d\'anormal', () => _alertDecision(a, 'ack'), c.primary),
            if ('${a['pub']}'.startsWith('ap_') && a['autoHold'] != true) ('Bloquer les paiements', () => _alertDecision(a, 'hold'), null),
            if ('${a['pub']}'.startsWith('ap_') && a['autoHold'] == true) ('Lever le blocage', () => _alertDecision(a, 'release'), null),
          ]),
        ]),
    ]);
  }

  Widget _propsTab(AppColors c) {
    if (_props.isEmpty) return _empty(c, 'Aucun site ni application dans cette liste.');
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final p in _props)
        _card(c, children: [
          Row(children: [
            Icon(p['kind'] == 'site' ? Icons.language_rounded : Icons.phone_android_rounded, color: c.info),
            const SizedBox(width: 8),
            Expanded(child: Text('${p['name']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          _kv(c, 'Identifiant', '${p['id']}'),
          _kv(c, 'Diffuseur', '${p['ownerName']} · ${p['ownerEmail']}'),
          _kv(c, 'Profil du diffuseur', switch ('${p['ownerStatus']}') { 'active' => 'Validé', 'pending' => 'En attente (à valider d\'abord)', 'refused' => 'Refusé', 'suspended' => 'Suspendu', _ => 'Aucun' }),
          _link(c, '${p['url']}'.isNotEmpty ? '${p['url']}' : '', '${p['url'] ?? ''}'),
          _link(c, '${p['androidUrl']}'.isNotEmpty ? 'Google Play' : '', '${p['androidUrl'] ?? ''}'),
          _link(c, '${p['iosUrl']}'.isNotEmpty ? 'App Store' : '', '${p['iosUrl'] ?? ''}'),
          _kv(c, 'Catégorie, pays', '${p['category']} · ${(p['countries'] as List? ?? const []).join(', ')}'),
          _kv(c, 'Audience déclarée', '${p['audienceMonthly']} par mois'),
          if (p['status'] == 'active') _kv(c, 'Audience retenue', '${p['audienceCounted']}'),
          _kv(c, 'En ligne (vérifié)', p['online'] == true ? 'Oui${p['protectedSite'] == true ? ' (site protégé contre les robots)' : ''}' : 'Non'),
          _kv(c, 'Propriété du site', p['verified'] == true ? 'Vérifiée ✓' : 'Non vérifiée'),
          _kv(c, 'Rémunérable', p['payable'] == true ? 'Oui' : 'Non (site non vérifié ou application non attestée)'),
          _kv(c, 'Catégories acceptées', (p['acceptedCategories'] as List? ?? const []).isEmpty ? 'courantes par défaut' : (p['acceptedCategories'] as List).join(', ')),
          _kv(c, 'Audience mesurée', _measured(p['measured'])),
          _kv(c, 'Description', '${p['description']}'),
          if ('${p['reason'] ?? ''}'.isNotEmpty) _kv(c, 'Motif', '${p['reason']}'),
          _buttons(c, items: [
            if (p['status'] == 'pending' || p['status'] == 'refused') ('Valider', () => _propDecision(p, 'approve'), c.primary),
            if (p['status'] == 'suspended') ('Réactiver', () => _propDecision(p, 'reactivate'), c.primary),
            if (p['status'] == 'pending') ('Refuser', () => _propDecision(p, 'refuse'), null),
            if (p['status'] == 'active') ('Suspendre', () => _propDecision(p, 'suspend'), null),
          ]),
        ]),
    ]);
  }

  String _statusLabel(Object? s) => switch ('$s') { 'pending' => 'En validation', 'active' => 'Validé', 'refused' => 'Refusé', 'suspended' => 'Suspendu', _ => '$s' };

  /// Partageurs « Partage et gagne » : utilisateurs de l'application dont l'audience WhatsApp, Telegram ou groupes est à valider avant leurs premières missions.
  Widget _sharersTab(AppColors c) {
    if (_sharers.isEmpty) return _empty(c, 'Aucun partageur dans cette liste.');
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final p in _sharers)
        _card(c, children: [
          Row(children: [
            Icon(Icons.campaign_rounded, color: c.info),
            const SizedBox(width: 8),
            Expanded(child: Text('${p['name'] ?? ''}'.isNotEmpty ? '${p['name']}' : '${p['email'] ?? p['uid']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          _kv(c, 'Statut', _statusLabel(p['status'])),
          _kv(c, 'Pays, ville', '${p['country'] ?? ''}${'${p['city'] ?? ''}'.isNotEmpty ? ', ${p['city']}' : ''}'),
          _kv(c, 'Contact', '${p['whatsapp'] ?? ''} · ${p['email'] ?? ''}'),
          _kv(c, 'Audience déclarée', '${p['declared'] ?? 0} personnes (statut ${p['statusAudience'] ?? 0}, Telegram ${p['telegramAudience'] ?? 0}, autres ${p['otherAudience'] ?? 0}, ${(p['groups'] as List? ?? const []).length} groupes)'),
          if ((p['groups'] as List? ?? const []).isNotEmpty) _kv(c, 'Groupes', (p['groups'] as List).map((g) => '${(g as Map)['name']} (${g['members']})').join(', ')),
          _kv(c, 'Présentation', '${p['about'] ?? ''}'),
          if (p['status'] == 'active') _kv(c, 'Audience retenue', '${p['retained'] ?? 0}'),
          if (p['fraudHold'] == true) _kv(c, 'Gains', 'Bloqués : fraude possible'),
          if ('${p['reason'] ?? ''}'.isNotEmpty) _kv(c, 'Motif', '${p['reason']}'),
          _buttons(c, items: [
            if (p['status'] == 'pending' || p['status'] == 'refused') ('Valider', () => _sharerDecision(p, 'approve'), c.primary),
            if (p['status'] == 'suspended') ('Réactiver', () => _sharerDecision(p, 'reactivate'), c.primary),
            if (p['status'] == 'pending') ('Refuser', () => _sharerDecision(p, 'refuse'), null),
            if (p['status'] == 'active') ('Suspendre', () => _sharerDecision(p, 'suspend'), null),
            if (p['fraudHold'] == true) ('Vérifié : lever le blocage', () => _sharerDecision(p, 'clear'), null),
            if (p['status'] != 'refused') ('Fraude confirmée : retirer les gains', () => _sharerDecision(p, 'fraud'), null),
          ]),
        ]),
    ]);
  }

  /// Campagnes Partage : à valider une fois le paiement reçu (les campagnes de l'équipe sont offertes et actives tout de suite).
  Widget _campsTab(AppColors c) {
    if (_camps.isEmpty) return _empty(c, 'Aucune campagne Partage dans cette liste.');
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final p in _camps)
        _card(c, children: [
          Text('${p['brand'] ?? ''} · ${p['title'] ?? ''}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
          _kv(c, 'Statut', switch ('${p['status']}') { 'pending' => 'À valider', 'active' => 'En cours', 'paused' => 'En pause', 'refused' => 'Refusée', 'ended' => 'Terminée', _ => '${p['status']}' }),
          _kv(c, 'Annonceur', '${p['ownerEmail'] ?? ''}'),
          _kv(c, 'Texte', '${p['text'] ?? ''}'),
          _kv(c, 'Audience à atteindre', '${p['targetAudience'] ?? 0} personnes'),
          _kv(c, 'Prix', p['free'] == true ? 'Offerte par l\'équipe' : '${p['listPriceFcfa'] ?? 0} F (à encaisser avant de valider)'),
          _kv(c, 'Pays', (p['countries'] as List? ?? const []).join(', ')),
          _kv(c, 'Résultats', '${p['valid'] ?? 0} clics valides · ${p['sharers'] ?? 0} partageurs · audience engagée ${p['allocatedReach'] ?? 0}'),
          _kv(c, 'Audience touchée', '${p['provenReach'] ?? 0} personnes (publications confirmées) · ${p['uniqueOpens'] ?? 0} ouvertures · ${p['previews'] ?? 0} aperçus · ${p['declaredViews'] ?? 0} vues déclarées'),
          _link(c, 'Voir le lien de l\'annonceur', '${p['actionUrl'] ?? ''}'),
          if ('${p['reason'] ?? ''}'.isNotEmpty) _kv(c, 'Motif', '${p['reason']}'),
          _buttons(c, items: [
            if (p['status'] == 'pending') ('Valider (paiement reçu)', () => _campDecision(p, 'approve'), c.primary),
            if (p['status'] == 'pending') ('Refuser', () => _campDecision(p, 'refuse'), null),
            if (p['status'] == 'active') ('Mettre en pause', () => _campDecision(p, 'pause'), null),
            if (p['status'] == 'active') ('Terminer', () => _campDecision(p, 'end'), null),
            if (p['status'] == 'paused') ('Reprendre', () => _campDecision(p, 'resume'), c.primary),
          ]),
        ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const filters ={'all': 'Tous', 'pending': 'En attente', 'active': 'Validés', 'refused': 'Refusés', 'suspended': 'Suspendus'};
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          foregroundColor: c.textPrimary,
          title: const Text('Régie : annonceurs, diffuseurs, partageurs'),
          bottom: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(text: 'Annonceurs (${_logos.length})'),
            Tab(text: 'Diffuseurs (${_profiles.length})'),
            Tab(text: 'Sites et applis (${_props.length})'),
            Tab(text: 'Partageurs (${_sharers.length})'),
            Tab(text: 'Campagnes (${_camps.length})'),
            Tab(text: 'Alertes (${_alerts.length})'),
          ]),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Actualiser')],
        ),
        body: CenteredContent(
          child: Column(children: [
            SizedBox(
              height: 52,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
                for (final e in filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(e.value), selected: _filter == e.key, onSelected: (_) { setState(() => _filter = e.key); _load(); }),
                  ),
              ]),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: c.danger))))
                      : TabBarView(children: [_logosTab(c), _profilesTab(c), _propsTab(c), _sharersTab(c), _campsTab(c), _alertsTab(c)]),
            ),
          ]),
        ),
      ),
    );
  }
}
