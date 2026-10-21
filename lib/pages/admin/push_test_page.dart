import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/services/read_meter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';

/// Essai des notifications push (administrateurs) : envoie un message de test aux administrateurs, à soi-même ou à une personne précise,
/// et montre par quel canal il est parti (FCM, OneSignal, ou aucun) ainsi que l'état d'enregistrement de chaque appareil.
class PushTestPage extends StatefulWidget {
  const PushTestPage({super.key});

  @override
  State<PushTestPage> createState() => _PushTestPageState();
}

enum _Target { admins, me, person }

class _PushTestPageState extends State<PushTestPage> {
  _Target _target = _Target.admins;
  final _search = TextEditingController();
  final _title = TextEditingController(text: 'Test Afrolook');
  late final TextEditingController _message = TextEditingController(text: 'Notification de test envoyée à ${_now()}');

  bool _searching = false;
  bool _sending = false;
  String? _error;
  List<_Person> _found = [];
  _Person? _selected;
  _Person? _me;
  Map<String, dynamic>? _result;
  List<_Person> _recipients = [];

  // ── Exemples de chaque cas de notification (aux administrateurs) ──
  List<Map<String, dynamic>> _cases = [];
  bool _casesLoading = false;
  bool _casesSending = false;
  bool _samplesToMe = false;
  String? _samplesStatus;

  Future<void> _loadCases() async {
    setState(() {
      _casesLoading = true;
      _samplesStatus = null;
    });
    try {
      final res = await FirebaseFunctions.instance.httpsCallable('sendNotificationSamples').call({'list': true});
      final list = ((res.data as Map)['cases'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (mounted) setState(() => _cases = list);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _samplesStatus = e.code == 'not-found' ? 'La fonction sendNotificationSamples n\'est pas encore déployée.' : 'Refusé (${e.code}) : ${e.message ?? ''}');
    } catch (e) {
      if (mounted) setState(() => _samplesStatus = 'Impossible de charger la liste : $e');
    }
    if (mounted) setState(() => _casesLoading = false);
  }

  Future<void> _sendCases(Object cases, String label) async {
    setState(() {
      _casesSending = true;
      _samplesStatus = 'Envoi de « $label » en cours…';
    });
    try {
      final res = await FirebaseFunctions.instance.httpsCallable('sendNotificationSamples').call({'cases': cases, 'target': _samplesToMe ? 'me' : 'admins'});
      final d = Map<String, dynamic>.from(res.data as Map);
      if (mounted) setState(() => _samplesStatus = '✅ ${d['sent']} notification(s) envoyée(s) à ${d['recipients']} personne(s). Elles arrivent une à une.');
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _samplesStatus = 'Refusé (${e.code}) : ${e.message ?? ''}');
    } catch (e) {
      if (mounted) setState(() => _samplesStatus = 'Envoi impossible : $e');
    }
    if (mounted) setState(() => _casesSending = false);
  }

  Widget _samplesSection(AppColors colors, Widget Function(Widget) card, Text Function(String) label) {
    const groups = {'rappels': 'Rappels programmés', 'pedagogiques': 'Notifications pédagogiques (langue de votre profil)', 'activite': 'Activité et événements'};
    return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      label('Exemples de chaque cas'),
      const SizedBox(height: 4),
      Text('Envoie une vraie notification de test par cas (titre « 🧪 TEST »), avec son image d\'aperçu et son action au clic, pour vérifier à quoi elle ressemble et où elle mène.',
          style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.3)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        ChoiceChip(label: const Text('Tous les administrateurs'), selected: !_samplesToMe, onSelected: (_) => setState(() => _samplesToMe = false)),
        ChoiceChip(label: const Text('Moi seulement'), selected: _samplesToMe, onSelected: (_) => setState(() => _samplesToMe = true)),
      ]),
      const SizedBox(height: 8),
      if (_cases.isEmpty)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _casesLoading ? null : _loadCases,
            icon: _casesLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.list_alt_rounded),
            label: const Text('Afficher les cas'),
          ),
        )
      else ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _casesSending ? null : () => _sendCases('all', 'tous les cas'),
            icon: const Icon(Icons.send_rounded),
            label: Text('Tout envoyer (${_cases.length} notifications)'),
          ),
        ),
        for (final g in groups.entries)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('${g.value} (${_cases.where((c) => c['group'] == g.key).length})', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _casesSending ? null : () => _sendCases(g.key, g.value),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Envoyer ce groupe'),
                ),
              ),
              for (final c in _cases.where((c) => c['group'] == g.key))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${c['label']}', style: TextStyle(color: colors.textPrimary, fontSize: 12.5)),
                  subtitle: c['hasImage'] == true ? Text('avec image d\'aperçu', style: TextStyle(color: colors.textSecondary, fontSize: 11)) : null,
                  trailing: TextButton(onPressed: _casesSending ? null : () => _sendCases(c['id'], '${c['label']}'), child: const Text('Envoyer')),
                ),
            ],
          ),
      ],
      if (_samplesStatus != null)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(_samplesStatus!, style: TextStyle(color: colors.textSecondary, fontSize: 12))),
    ]));
  }

  static String _now() {
    final d = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    return '${t(d.hour)}:${t(d.minute)}:${t(d.second)}';
  }

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  @override
  void dispose() {
    _search.dispose();
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    final id = context.read<UserAuthProvider>().loginUserData.id;
    if (id == null || id.isEmpty) return;
    final p = await _fetchById(id);
    if (mounted) setState(() => _me = p);
  }

  Future<_Person?> _fetchById(String id) async {
    final snap = await FirebaseFirestore.instance.collection('Users').doc(id).getM('push_test_page.dart:byId');
    if (!snap.exists) return null;
    return _Person.from(snap.id, snap.data()!);
  }

  /// Cherche par pseudo exact (avec ou sans @) ou par identifiant de profil.
  Future<void> _find() async {
    final q = _search.text.trim().replaceFirst(RegExp(r'^@'), '');
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _found = [];
      _selected = null;
    });
    try {
      final out = <_Person>[];
      final byId = q.length > 15 && !q.contains(' ') ? await _fetchById(q) : null;
      if (byId != null) out.add(byId);
      if (out.isEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('Users')
            .where('pseudo', isEqualTo: q)
            .limit(5)
            .getM('push_test_page.dart:pseudo');
        out.addAll(snap.docs.map((d) => _Person.from(d.id, d.data())));
      }
      if (!mounted) return;
      setState(() {
        _found = out;
        _selected = out.length == 1 ? out.first : null;
        if (out.isEmpty) _error = 'Aucune personne trouvée pour « $q ».';
        _searching = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Recherche impossible : $e';
        _searching = false;
      });
    }
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) {
      setState(() => _error = 'Écrivez un message.');
      return;
    }
    final payload = <String, dynamic>{
      'title': _title.text.trim().isEmpty ? 'Test Afrolook' : _title.text.trim(),
      'message': _message.text.trim(),
      'details': true,
      'data': {'type_notif': 'TEST'},
    };
    switch (_target) {
      case _Target.admins:
        payload['toAdmins'] = true;
        break;
      case _Target.me:
        final id = _me?.id;
        if (id == null) {
          setState(() => _error = 'Votre profil n\'est pas chargé.');
          return;
        }
        payload['userIds'] = [id];
        break;
      case _Target.person:
        if (_selected == null) {
          setState(() => _error = 'Choisissez d\'abord une personne.');
          return;
        }
        payload['userIds'] = [_selected!.id];
        break;
    }
    setState(() {
      _sending = true;
      _error = null;
      _result = null;
    });
    try {
      final res = await FirebaseFunctions.instance.httpsCallable('sendPushToUsers').call(payload);
      final data = Map<String, dynamic>.from(res.data as Map);
      final details = ((data['details'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final people = <_Person>[];
      for (final d in details) {
        final id = d['userId']?.toString();
        if (id == null) continue;
        people.add(await _fetchById(id) ?? _Person(id: id, pseudo: id));
      }
      if (!mounted) return;
      setState(() {
        _result = data;
        _recipients = people;
        _sending = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() {
        _error = e.code == 'not-found'
            ? 'La fonction sendPushToUsers n\'est pas encore déployée sur le serveur.'
            : 'Envoi refusé (${e.code}) : ${e.message ?? ''}';
        _sending = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Envoi impossible : $e';
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget card(Widget child) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          child: child,
        );
    Text label(String s) => Text(s, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13));
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        title: const Text('Essai des notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Destinataire'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final t in _Target.values)
                ChoiceChip(
                  label: Text(switch (t) {
                    _Target.admins => 'Tous les administrateurs',
                    _Target.me => 'Moi',
                    _Target.person => 'Une personne',
                  }),
                  selected: _target == t,
                  onSelected: (_) => setState(() => _target = t),
                ),
            ]),
            if (_target == _Target.me && _me != null) ...[
              const SizedBox(height: 10),
              _PersonTile(person: _me!),
            ],
            if (_target == _Target.person) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: deco('Pseudo (ou identifiant du profil)'),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _find(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searching ? null : _find,
                  child: _searching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Chercher'),
                ),
              ]),
              for (final p in _found)
                InkWell(
                  onTap: () => setState(() => _selected = p),
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _selected?.id == p.id ? colors.primary : colors.border, width: _selected?.id == p.id ? 2 : 1),
                    ),
                    child: _PersonTile(person: p),
                  ),
                ),
            ],
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Message'),
            const SizedBox(height: 8),
            TextField(controller: _title, decoration: deco('Titre'), maxLength: 80),
            const SizedBox(height: 4),
            TextField(controller: _message, decoration: deco('Texte de la notification'), maxLines: 3, maxLength: 300),
          ])),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.notifications_active_rounded),
              label: const Text('Envoyer la notification de test'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: colors.warning, fontSize: 13)),
            ),
          _samplesSection(colors, card, label),
          if (_result != null) ...[
            const SizedBox(height: 14),
            card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              label('Résultat'),
              const SizedBox(height: 6),
              Text(
                'Par FCM : ${_result!['fcm']} appareil(s) · Par OneSignal : ${_result!['oneSignal']} personne(s) · Non jointes : ${(_result!['unreachable'] as num).toInt() < 0 ? 0 : _result!['unreachable']}',
                style: TextStyle(color: colors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              for (final d in ((_result!['details'] as List?) ?? const []))
                _ResultRow(detail: Map<String, dynamic>.from(d as Map), person: _recipients.where((p) => p.id == d['userId']).firstOrNull),
              if (((_result!['details'] as List?) ?? const []).isEmpty)
                Text('Aucun destinataire trouvé.', style: TextStyle(color: colors.textSecondary, fontSize: 12.5)),
            ])),
            Text(
              'FCM = canal Firebase (sans quota). OneSignal = ancien canal, limité par le quota. « aucun » = la personne n\'a ni appareil enregistré en FCM ni identifiant OneSignal exploitable, ou OneSignal est en pause.',
              style: TextStyle(color: colors.textSecondary, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Résumé d'un profil et de l'état de ses notifications.
class _Person {
  _Person({required this.id, required this.pseudo, this.imageUrl, this.fcmDevices = 0, this.hasOneSignal = false, this.platform});
  final String id;
  final String pseudo;
  final String? imageUrl;
  final int fcmDevices;
  final bool hasOneSignal;
  final String? platform;

  factory _Person.from(String id, Map<String, dynamic> d) => _Person(
        id: id,
        pseudo: (d['pseudo'] ?? d['nom'] ?? id).toString(),
        imageUrl: (d['imageUrl'] ?? '').toString().isEmpty ? null : d['imageUrl'].toString(),
        fcmDevices: d['fcmTokens'] is List ? (d['fcmTokens'] as List).length : 0,
        hasOneSignal: (d['oneIgnalUserid'] ?? '').toString().length > 5,
        platform: d['platform']?.toString(),
      );
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person});
  final _Person person;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundImage: person.imageUrl != null ? NetworkImage(person.imageUrl!) : null,
        child: person.imageUrl == null ? const Icon(Icons.person, size: 18) : null,
      ),
      title: Text('@${person.pseudo}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
      subtitle: Text(
        'FCM : ${person.fcmDevices} appareil(s) · OneSignal : ${person.hasOneSignal ? 'oui' : 'non'}${person.platform != null ? ' · ${person.platform}' : ''}',
        style: TextStyle(color: colors.textSecondary, fontSize: 12),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.detail, required this.person});
  final Map<String, dynamic> detail;
  final _Person? person;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final channel = detail['channel']?.toString() ?? 'aucun';
    final ok = channel != 'aucun';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: ok ? colors.success : colors.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '@${person?.pseudo ?? detail['userId']} — $channel (appareils FCM : ${detail['tokens']}, OneSignal : ${detail['hasOneSignalId'] == true ? 'oui' : 'non'})',
            style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
          ),
        ),
      ]),
    );
  }
}
