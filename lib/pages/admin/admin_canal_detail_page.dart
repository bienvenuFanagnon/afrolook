import 'package:afrotok/widgets/name_tag.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/model_data.dart';
import '../../theme/app_colors.dart';
import '../../widgets/safe_network_avatar.dart';
import '../canaux/canal_manage_admins.dart';
import '../canaux/detailsCanal.dart';
import '../canaux/listCanalfollowers.dart';
import '../user/profile/retraitAdmin/userAllDetails.dart';

/// Fiche de gestion d'un canal par l'administrateur : statut, inactivité et toutes les opérations
/// (bloquer / débloquer, vérifier, mettre en avant, relancer le compteur, message au propriétaire, supprimer).
/// Les actions passent par la Cloud Function `adminCanalAction` (droits admin vérifiés côté serveur, journalisées).
class AdminCanalDetailPage extends StatefulWidget {
  final String canalId;
  const AdminCanalDetailPage({super.key, required this.canalId});

  @override
  State<AdminCanalDetailPage> createState() => _AdminCanalDetailPageState();
}

class _AdminCanalDetailPageState extends State<AdminCanalDetailPage> {
  static const int _dayMs = 24 * 60 * 60 * 1000;
  bool _busy = false;
  String? _ownerPseudo;
  String? _ownerLoadedFor;

  Future<void> _loadOwner(String? ownerId) async {
    if (ownerId == null || ownerId.isEmpty || _ownerLoadedFor == ownerId) return;
    _ownerLoadedFor = ownerId;
    try {
      final u = await FirebaseFirestore.instance.collection('Users').doc(ownerId).get();
      if (mounted) setState(() => _ownerPseudo = u.data()?['pseudo'] as String?);
    } catch (_) {}
  }

  int _lastAdded = 0;

  Future<bool> _call(String action, {int? days, String? message, int? count}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    try {
      final r = await FirebaseFunctions.instance.httpsCallable('adminCanalAction').call({
        'canalId': widget.canalId,
        'action': action,
        if (days != null) 'days': days,
        if (message != null) 'message': message,
        if (count != null) 'count': count,
      });
      _lastAdded = ((r.data as Map?)?['added'] as num?)?.toInt() ?? 0;
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec : ${e.message ?? e.code}'), backgroundColor: Colors.red));
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec : $e'), backgroundColor: Colors.red));
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _ok(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  Future<bool> _confirm(String title, String body, {String yes = 'Confirmer', bool danger = false}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
            child: Text(yes),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _block(bool block) async {
    if (!await _confirm(block ? 'Bloquer ce canal ?' : 'Débloquer ce canal ?',
        block
            ? 'Plus personne ne pourra publier dans ce canal. Le propriétaire est prévenu.'
            : 'Le canal est débloqué gratuitement et son compteur d\'inactivité repart à zéro. Le propriétaire est prévenu.',
        yes: block ? 'Bloquer' : 'Débloquer', danger: block)) return;
    if (await _call(block ? 'block' : 'unblock')) _ok(block ? 'Canal bloqué' : 'Canal débloqué');
  }

  Future<void> _verify(bool verify) async {
    if (await _call(verify ? 'verify' : 'unverify')) _ok(verify ? 'Canal vérifié' : 'Vérification retirée');
  }

  Future<void> _popular() async {
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Mettre le canal en avant'),
        children: [
          for (final d in [7, 30, 90, 0])
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, d), child: Text(d == 0 ? 'Sans limite de durée' : 'Pendant $d jours')),
        ],
      ),
    );
    if (days == null) return;
    if (await _call('popular', days: days)) _ok('Canal mis en avant');
  }

  Future<void> _unpopular() async {
    if (await _call('unpopular')) _ok('Canal retiré de la mise en avant');
  }

  Future<void> _reset() async {
    if (!await _confirm('Relancer le compteur d\'inactivité ?', 'Le canal repart pour 20 jours sans blocage (le rappel est effacé).')) return;
    if (await _call('reset_inactivity')) _ok('Compteur remis à zéro');
  }

  Future<void> _fillFollowers() async {
    final ctrl = TextEditingController();
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter des abonnés'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Combien d\'abonnés ajouter ? Ils sont pris parmi les comptes les plus suivis qui ne suivent pas encore ce canal (5000 maximum).'),
          const SizedBox(height: 10),
          TextField(controller: ctrl, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(hintText: 'Ex : 500')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (n == null) return;
    if (await _call('fill_followers', count: n)) _ok('$_lastAdded abonné(s) ajouté(s)');
  }

  Future<void> _notify() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Message au propriétaire'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(hintText: 'Écris le message (envoyé en notification)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Envoyer')),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty) return;
    if (await _call('notify', message: text)) _ok('Message envoyé');
  }

  Future<void> _delete(String titre) async {
    if (!await _confirm('Supprimer le canal ?',
        'Le canal « $titre », toutes ses publications et ses médias seront supprimés définitivement. Cette action est irréversible.',
        yes: 'Continuer', danger: true)) return;
    if (!await _confirm('Dernière confirmation', 'Supprimer définitivement #$titre ?', yes: 'Oui, supprimer', danger: true)) return;
    if (await _call('delete')) {
      _ok('Canal supprimé');
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Gestion du canal', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('Canaux').doc(widget.canalId).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erreur : ${snap.error}', style: TextStyle(color: c.danger)));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final doc = snap.data!;
          if (!doc.exists) return Center(child: Text('Ce canal n\'existe plus.', style: TextStyle(color: c.textSecondary)));
          final d = doc.data()!;
          _loadOwner(d['userId'] as String?);
          return Stack(children: [
            ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 32), children: _sections(c, d)),
            if (_busy)
              Positioned.fill(
                child: Container(color: Colors.black38, child: const Center(child: CircularProgressIndicator())),
              ),
          ]);
        },
      ),
    );
  }

  static int _ms(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return n > 100000000000000 ? n ~/ 1000 : n;
  }

  List<Widget> _sections(AppColors c, Map<String, dynamic> d) {
    final titre = (d['titre'] ?? '').toString();
    final ownerId = d['userId'] as String?;
    final blocked = d['isBlocked'] == true;
    final verified = d['isVerify'] == true;
    final now = DateTime.now().millisecondsSinceEpoch;
    final popularUntil = (d['popularUntil'] as num?)?.toInt() ?? 0;
    final popular = d['isPopular'] == true && (popularUntil == 0 || popularUntil > now);
    final followersList = d['usersSuiviId'] is List ? List<String>.from((d['usersSuiviId'] as List).whereType<String>()) : <String>[];
    final followers = followersList.length > ((d['suivi'] as num?)?.toInt() ?? 0) ? followersList.length : ((d['suivi'] as num?)?.toInt() ?? 0);
    final posts = (d['publication'] as num?)?.toInt() ?? 0;
    final lastPostAt = _ms(d['lastPostAt']);
    final daysInactive = lastPostAt > 0 ? ((now - lastPostAt) / _dayMs).floor() : null;
    final created = _ms(d['createdAt']);
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final score = (d['canalScore'] as num?)?.toDouble() ?? 0;

    return [
      // En-tête
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: Row(children: [
          SafeNetworkAvatar(url: d['urlImage'] as String?, radius: 32, backgroundColor: c.surfaceVariant, iconColor: c.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: NameTag(label: '#$titre', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                if (verified) ...[const SizedBox(width: 5), Icon(Icons.verified_rounded, size: 18, color: c.info)],
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (blocked) _badge(c.danger, d['blockReason'] == 'admin' ? 'Bloqué par un admin' : 'Bloqué (inactivité)') else _badge(c.primary, 'Actif'),
                if (popular) _badge(c.warning, 'Mis en avant'),
                if (d['isPrivate'] == true) _badge(c.info, 'Privé'),
              ]),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // Chiffres
      Row(children: [
        _stat(c, '$followers', 'Abonnés'),
        _stat(c, '$posts', 'Publications'),
        _stat(c, score.toStringAsFixed(1), 'Score'),
      ]),
      const SizedBox(height: 12),

      // Inactivité
      _card(c, 'Activité', [
        _row(c, 'Dernière publication', lastPostAt > 0 ? '${fmt.format(DateTime.fromMillisecondsSinceEpoch(lastPostAt))} (il y a $daysInactive j)' : 'inconnue'),
        _row(c, 'Créé le', created > 0 ? fmt.format(DateTime.fromMillisecondsSinceEpoch(created)) : 'inconnu'),
        if (blocked && _ms(d['blockedAt']) > 0) _row(c, 'Bloqué le', fmt.format(DateTime.fromMillisecondsSinceEpoch(_ms(d['blockedAt'])))),
        if (_ms(d['inactivityWarnedAt']) > 0) _row(c, 'Rappel envoyé le', fmt.format(DateTime.fromMillisecondsSinceEpoch(_ms(d['inactivityWarnedAt'])))),
        if (popular && popularUntil > 0) _row(c, 'Mis en avant jusqu\'au', fmt.format(DateTime.fromMillisecondsSinceEpoch(popularUntil))),
      ]),
      const SizedBox(height: 12),

      // Propriétaire
      _card(c, 'Propriétaire', [
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(Icons.person_rounded, color: c.textSecondary),
          title: Text(_ownerPseudo != null ? '@$_ownerPseudo' : (ownerId ?? 'inconnu'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Text('Ouvrir sa fiche de gestion', style: TextStyle(color: c.textSecondary, fontSize: 12)),
          trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
          onTap: ownerId == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserManagementPage(userId: ownerId))),
        ),
      ]),
      const SizedBox(height: 12),

      // Opérations
      _card(c, 'Opérations', [
        _action(c, blocked ? Icons.lock_open_rounded : Icons.lock_rounded, blocked ? 'Débloquer le canal' : 'Bloquer le canal',
            blocked ? 'Gratuit, relance le compteur d\'inactivité' : 'Plus aucune publication possible', blocked ? c.primary : c.danger, () => _block(!blocked)),
        _action(c, verified ? Icons.remove_moderator_rounded : Icons.verified_rounded, verified ? 'Retirer la vérification' : 'Vérifier le canal',
            'Badge de certification', c.info, () => _verify(!verified)),
        _action(c, popular ? Icons.star_border_rounded : Icons.star_rounded, popular ? 'Retirer de la mise en avant' : 'Populariser le canal',
            popular ? 'Le canal n\'est plus en tête des suggestions' : 'En tête des suggestions et de la recherche', c.warning, popular ? _unpopular : _popular),
        _action(c, Icons.restart_alt_rounded, 'Relancer le compteur d\'inactivité', 'Repart pour 20 jours, efface le rappel', c.textPrimary, _reset),
        _action(c, Icons.group_add_rounded, 'Ajouter des abonnés', 'Comptes actifs les plus suivis', c.textPrimary, _fillFollowers),
        _action(c, Icons.campaign_rounded, 'Envoyer un message au propriétaire', 'Notification dans l\'app', c.textPrimary, _notify),
      ]),
      const SizedBox(height: 12),

      // Consulter / gérer
      _card(c, 'Consulter', [
        _action(c, Icons.open_in_new_rounded, 'Ouvrir le canal', 'Voir le canal comme un utilisateur', c.textPrimary, () {
          final canal = Canal.fromJson(d)..id = widget.canalId;
          Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: canal)));
        }),
        _action(c, Icons.groups_rounded, 'Voir les abonnés ($followers)', 'Liste des abonnés', c.textPrimary, () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelFollowersPage(userIds: followersList, channelName: titre)));
        }),
        _action(c, Icons.admin_panel_settings_rounded, 'Administrateurs du canal', 'Ajouter ou retirer des administrateurs', c.textPrimary, () {
          final canal = Canal.fromJson(d)..id = widget.canalId;
          Navigator.push(context, MaterialPageRoute(builder: (_) => CanalManageAdminsPage(canal: canal)));
        }),
      ]),
      const SizedBox(height: 12),

      // Zone dangereuse
      _card(c, 'Zone dangereuse', [
        _action(c, Icons.delete_forever_rounded, 'Supprimer le canal', 'Supprime le canal, ses posts et ses médias (irréversible)', c.danger, () => _delete(titre)),
      ]),
    ];
  }

  Widget _card(AppColors c, String title, List<Widget> children) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: TextStyle(color: c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          ...children,
        ]),
      );

  Widget _row(AppColors c, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: Text(k, style: TextStyle(color: c.textSecondary, fontSize: 13))),
          Expanded(flex: 6, child: Text(v, textAlign: TextAlign.right, style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _stat(AppColors c, String value, String label) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(children: [
            Text(value, style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
          ]),
        ),
      );

  Widget _badge(Color color, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _action(AppColors c, IconData icon, String title, String subtitle, Color color, VoidCallback onTap) => ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: TextStyle(color: color == c.textPrimary ? c.textPrimary : color, fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: c.textSecondary, fontSize: 12)),
        trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 20),
        onTap: _busy ? null : onTap,
      );
}
