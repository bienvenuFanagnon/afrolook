import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../layout/centered_content.dart';

// ─── Constantes ─────────────────────────────────────────────────────────────

const _widgetLabels = {
  'stats_inscriptions': 'Statistiques des inscriptions',
};

// ─── Page admin gestion équipe ────────────────────────────────────────────────

class TeamAdminPage extends StatefulWidget {
  const TeamAdminPage({super.key});

  @override
  State<TeamAdminPage> createState() => _TeamAdminPageState();
}

class _TeamAdminPageState extends State<TeamAdminPage> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion d\'équipe', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tab,
          labelColor: colors.primary,
          indicatorColor: colors.primary,
          tabs: const [
            Tab(text: 'Profils'),
            Tab(text: 'Membres'),
          ],
        ),
      ),
      body: SafeArea(
        child: CenteredContent(
          maxWidth: 800,
          child: TabBarView(
            controller: _tab,
            children: const [
              _ProfilesTab(),
              _MembersTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Onglet Profils ──────────────────────────────────────────────────────────

class _ProfilesTab extends StatefulWidget {
  const _ProfilesTab();

  @override
  State<_ProfilesTab> createState() => _ProfilesTabState();
}

class _ProfilesTabState extends State<_ProfilesTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _profiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await FirebaseFunctions.instance.httpsCallable('getTeamProfiles').call();
      final data = Map<String, dynamic>.from(res.data);
      if (!mounted) return;
      setState(() {
        _profiles = List<Map<String, dynamic>>.from(
            (data['profiles'] as List).map((p) => Map<String, dynamic>.from(p)));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _showCreateDialog({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final selectedWidgets = <String>{...((existing?['widgets'] ?? []) as List).cast<String>()};
    final colors = AppColors.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: Text(existing == null ? 'Nouveau profil' : 'Modifier le profil'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom du profil', hintText: 'ex: Stagiaire'),
              ),
              const SizedBox(height: 16),
              const Text('Widgets visibles :', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._widgetLabels.entries.map((e) => CheckboxListTile(
                value: selectedWidgets.contains(e.key),
                title: Text(e.value, style: const TextStyle(fontSize: 14)),
                activeColor: colors.primary,
                dense: true,
                onChanged: (v) => setS(() => v! ? selectedWidgets.add(e.key) : selectedWidgets.remove(e.key)),
              )),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  if (existing == null) {
                    await FirebaseFunctions.instance.httpsCallable('manageTeamProfile').call({
                      'action': 'create',
                      'name': name,
                      'widgets': selectedWidgets.toList(),
                    });
                  } else {
                    await FirebaseFunctions.instance.httpsCallable('manageTeamProfile').call({
                      'action': 'update',
                      'profileId': existing['id'],
                      'name': name,
                      'widgets': selectedWidgets.toList(),
                    });
                  }
                  _load();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                }
              },
              child: Text(existing == null ? 'Créer' : 'Enregistrer'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce profil ?'),
        content: Text('Le profil "${p['name']}" et tous les accès associés seront supprimés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('manageTeamProfile')
          .call({'action': 'delete', 'profileId': p['id']});
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (_loading) return Center(child: CircularProgressIndicator(color: colors.primary));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text('${_profiles.length} profil(s)', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showCreateDialog(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nouveau profil'),
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: Colors.white),
          ),
        ]),
      ),
      Expanded(
        child: _profiles.isEmpty
            ? Center(child: Text('Aucun profil créé.', style: TextStyle(color: Colors.grey[400])))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _profiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = _profiles[i];
                  final widgets = List<String>.from(p['widgets'] ?? []);
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.primary.withOpacity(0.15)),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p['name'] as String,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: widgets.map((w) => Chip(
                              label: Text(_widgetLabels[w] ?? w, style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: colors.primary.withOpacity(0.1),
                            )).toList(),
                          ),
                        ]),
                      ),
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showCreateDialog(existing: p)),
                      IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent), onPressed: () => _delete(p)),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }
}

// ─── Onglet Membres ───────────────────────────────────────────────────────────

class _MembersTab extends StatefulWidget {
  const _MembersTab();

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _profiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        FirebaseFunctions.instance.httpsCallable('getTeamMembers').call(),
        FirebaseFunctions.instance.httpsCallable('getTeamProfiles').call(),
      ]);
      if (!mounted) return;
      final mData = Map<String, dynamic>.from(results[0].data);
      final pData = Map<String, dynamic>.from(results[1].data);
      setState(() {
        _members = List<Map<String, dynamic>>.from(
            (mData['members'] as List).map((m) => Map<String, dynamic>.from(m)));
        _profiles = List<Map<String, dynamic>>.from(
            (pData['profiles'] as List).map((p) => Map<String, dynamic>.from(p)));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _showAssignDialog() async {
    final emailCtrl = TextEditingController();
    String? selectedProfileId;
    final colors = AppColors.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Ajouter un membre'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'E-mail ou UID de l\'utilisateur'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedProfileId,
                decoration: const InputDecoration(labelText: 'Profil'),
                items: _profiles.map((p) => DropdownMenuItem<String>(
                  value: p['id'] as String,
                  child: Text(p['name'] as String),
                )).toList(),
                onChanged: (v) => setS(() => selectedProfileId = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: selectedProfileId == null
                  ? null
                  : () async {
                      final input = emailCtrl.text.trim();
                      if (input.isEmpty) return;
                      Navigator.pop(ctx);
                      try {
                        // Résoudre l'UID depuis l'email si besoin
                        String? uid;
                        if (input.contains('@')) {
                          final snap = await FirebaseFirestore.instance
                              .collection('Users')
                              .where('email', isEqualTo: input)
                              .limit(1)
                              .get();
                          if (snap.docs.isNotEmpty) uid = snap.docs.first.id;
                        } else {
                          uid = input;
                        }
                        if (uid == null) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Utilisateur introuvable')));
                          return;
                        }
                        await FirebaseFunctions.instance.httpsCallable('assignTeamProfile').call({
                          'action': 'assign',
                          'uid': uid,
                          'profileId': selectedProfileId,
                        });
                        _load();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: Colors.white),
              child: const Text('Ajouter'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _revoke(Map<String, dynamic> m) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Révoquer l\'accès ?'),
        content: Text('${m['pseudo'] ?? m['uid']} n\'aura plus accès au Hub Équipe.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Révoquer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('assignTeamProfile')
          .call({'action': 'revoke', 'uid': m['uid']});
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (_loading) return Center(child: CircularProgressIndicator(color: colors.primary));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Text('${_members.length} membre(s)', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _profiles.isEmpty ? null : _showAssignDialog,
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Ajouter'),
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: Colors.white),
          ),
        ]),
      ),
      if (_profiles.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Créez d\'abord un profil dans l\'onglet "Profils".',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
        ),
      Expanded(
        child: _members.isEmpty
            ? Center(child: Text('Aucun membre.', style: TextStyle(color: Colors.grey[400])))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final m = _members[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: (m['imageUrl'] as String?)?.isNotEmpty == true
                          ? NetworkImage(m['imageUrl'] as String)
                          : null,
                      backgroundColor: colors.primary.withOpacity(0.2),
                      child: (m['imageUrl'] as String?)?.isEmpty != false
                          ? Text((m['pseudo'] as String? ?? '?')[0].toUpperCase(),
                              style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    title: Text(m['pseudo'] as String? ?? m['uid'] as String,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${m['email'] ?? ''} · ${m['profileName'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          color: Colors.redAccent, size: 22),
                      onPressed: () => _revoke(m),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: Theme.of(context).cardColor,
                  );
                },
              ),
      ),
    ]);
  }
}
