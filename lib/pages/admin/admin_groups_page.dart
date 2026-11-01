import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/pages/admin/group_block_dialog.dart';
import 'package:afrotok/services/api/groups_b2_api.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Administration des groupes (équipe, permission `content.moderate`) : liste avec recherche et filtre « bloqués », blocage (motif obligatoire)
/// et déblocage. Un groupe bloqué ne reçoit plus de messages mais reste lisible par ses membres ; le propriétaire en est prévenu.
class AdminGroupsPage extends StatefulWidget {
  const AdminGroupsPage({super.key});

  @override
  State<AdminGroupsPage> createState() => _AdminGroupsPageState();
}

class _AdminGroupsPageState extends State<AdminGroupsPage> {
  final _search = TextEditingController();
  final List<AdminGroupRow> _rows = [];
  String? _next;
  bool _onlyBlocked = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await GroupsB2Api.adminList(q: _search.text, blocked: _onlyBlocked ? true : null);
      if (!mounted) return;
      setState(() {
        _rows
          ..clear()
          ..addAll(page.items);
        _next = page.next;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = GroupMessages.of(e);
        _loading = false;
      });
    }
  }

  Future<void> _more() async {
    if (_next == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await GroupsB2Api.adminList(q: _search.text, blocked: _onlyBlocked ? true : null, cursor: _next);
      if (!mounted) return;
      setState(() {
        _rows.addAll(page.items);
        _next = page.next;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(GroupMessages.of(e)), action: SnackBarAction(label: tr('Réessayer'), onPressed: _more)));
    }
  }

  Future<void> _toggle(AdminGroupRow g) async {
    final row = await toggleGroupBlock(context, groupId: g.id, groupName: g.name, currentlyBlocked: g.isBlocked);
    if (row == null || !mounted) return;
    setState(() {
      final i = _rows.indexWhere((r) => r.id == g.id);
      if (i >= 0) {
        if (_onlyBlocked && !row.isBlocked) {
          _rows.removeAt(i);
        } else {
          _rows[i] = row;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(tr('Groupes'), style: TextStyle(color: c.textPrimary, fontSize: 17)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(),
                    style: TextStyle(color: c.textPrimary),
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search),
                      hintText: tr('Nom du groupe'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(tr('Bloqués')),
                  selected: _onlyBlocked,
                  onSelected: (v) {
                    setState(() => _onlyBlocked = v);
                    _load();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: TextStyle(color: c.textSecondary)),
                            const SizedBox(height: 8),
                            ElevatedButton(onPressed: _load, child: Text(tr('Réessayer'))),
                          ],
                        ),
                      )
                    : _rows.isEmpty
                        ? Center(child: Text(tr('Aucun groupe trouvé.'), style: TextStyle(color: c.textSecondary)))
                        : ListView.builder(
                            itemCount: _rows.length + (_next != null ? 1 : 0),
                            itemBuilder: (ctx, i) {
                              if (i == _rows.length) {
                                return Center(
                                  child: _loadingMore
                                      ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                                      : TextButton(onPressed: _more, child: Text(tr('Voir plus'))),
                                );
                              }
                              final g = _rows[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: c.surfaceVariant,
                                  backgroundImage: g.imageUrl.isEmpty ? null : NetworkImage(g.imageUrl),
                                  child: g.imageUrl.isEmpty ? Icon(Icons.groups, color: c.textSecondary) : null,
                                ),
                                title: Text(g.name, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  [
                                    '@${g.ownerName}',
                                    tr('{n} membres', {'n': g.memberCount}),
                                    if (g.isPrivate) tr('privé, {n} pièces', {'n': g.priceCoins}),
                                    if (g.isBlocked && g.blockReason.isNotEmpty) tr('Motif : {m}', {'m': g.blockReason}),
                                  ].join(' · '),
                                  style: TextStyle(color: g.isBlocked ? Colors.red : c.textSecondary, fontSize: 12),
                                ),
                                trailing: TextButton(
                                  onPressed: () => _toggle(g),
                                  child: Text(g.isBlocked ? tr('Débloquer') : tr('Bloquer'), style: TextStyle(color: g.isBlocked ? Colors.green : Colors.red)),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
