import 'package:flutter/material.dart';

import '../../models/community_template.dart';
import '../../services/api/community_templates_api.dart';

/// Hub de modération des modèles créés par les utilisateurs (09/11/2026). Un modèle est publié tout de suite, sans validation préalable ; ici l'équipe voit tous les modèles,
/// peut en SUSPENDRE un (motif obligatoire, montré à son créateur), le RÉTABLIR ou le SUPPRIMER. Droit demandé côté serveur : `templates.manage`.
class AdminCommunityTemplatesPage extends StatefulWidget {
  const AdminCommunityTemplatesPage({super.key});

  @override
  State<AdminCommunityTemplatesPage> createState() => _AdminCommunityTemplatesPageState();
}

class _AdminCommunityTemplatesPageState extends State<AdminCommunityTemplatesPage> {
  String _status = 'validated';
  String _search = '';
  List<CommunityTemplate>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final rows = await CommunityTemplatesApi.adminList(status: _status, search: _search);
      if (mounted) setState(() => _items = rows);
    } catch (e) {
      if (mounted) setState(() => _error = '${(e as dynamic).message ?? e}');
    }
  }

  void _snack(String m) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(m)));

  Future<void> _suspend(CommunityTemplate t) async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Suspendre « ${t.name} »'),
        content: TextField(key: const ValueKey('suspend_reason'), controller: c, maxLength: 200, decoration: const InputDecoration(labelText: 'Motif (montré au créateur)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(key: const ValueKey('suspend_ok'), onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Suspendre')),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _run(() => CommunityTemplatesApi.adminReview(t.id, 'suspend', reason: reason), 'Modèle suspendu.');
  }

  Future<void> _delete(CommunityTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer « ${t.name} » ?'),
        content: const Text('Le modèle disparaît pour tout le monde. Les publications déjà faites restent ; les gains déjà versés restent acquis.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(key: const ValueKey('delete_ok'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => CommunityTemplatesApi.adminDelete(t.id), 'Modèle supprimé.');
  }

  Future<void> _run(Future<void> Function() act, String done) async {
    try {
      await act();
      _snack(done);
      await _load();
    } catch (e) {
      _snack('${(e as dynamic).message ?? e}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modèles des utilisateurs')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(children: [
            ChoiceChip(key: const ValueKey('status_validated'), label: const Text('Publiés'), selected: _status == 'validated', onSelected: (_) {
              _status = 'validated';
              _load();
            }),
            const SizedBox(width: 8),
            ChoiceChip(key: const ValueKey('status_suspended'), label: const Text('Suspendus'), selected: _status == 'suspended', onSelected: (_) {
              _status = 'suspended';
              _load();
            }),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const ValueKey('admin_search'),
                decoration: const InputDecoration(hintText: 'Rechercher un nom', isDense: true, prefixIcon: Icon(Icons.search)),
                onSubmitted: (v) {
                  _search = v.trim();
                  _load();
                },
              ),
            ),
          ]),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    final items = _items;
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return const Center(child: Text('Aucun modèle.'));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t = items[i];
        final suspended = t.status == 'suspended';
        return Card(
          key: ValueKey('admin_template_${t.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                '@${t.ownerName ?? '?'} · ${kCommunityCategories[t.category] ?? t.category} · ${t.priceCoins == 0 ? 'gratuit' : '${t.priceCoins} pièces'} · ${t.usesCount} utilisations · ${t.earnedCoins} pièces gagnées',
                style: const TextStyle(fontSize: 12.5),
              ),
              if (suspended && (t.refusalReason ?? '').isNotEmpty) Text('Motif : ${t.refusalReason}', style: const TextStyle(color: Colors.red, fontSize: 12.5)),
              Row(children: [
                if (!suspended) TextButton(key: ValueKey('suspend_${t.id}'), onPressed: () => _suspend(t), child: const Text('Suspendre')),
                if (suspended) TextButton(key: ValueKey('restore_${t.id}'), onPressed: () => _run(() => CommunityTemplatesApi.adminReview(t.id, 'restore'), 'Modèle rétabli.'), child: const Text('Rétablir')),
                TextButton(key: ValueKey('delete_${t.id}'), onPressed: () => _delete(t), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
