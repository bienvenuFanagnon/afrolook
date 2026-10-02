import 'package:afrotok/widgets/name_tag.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/safe_network_avatar.dart';
import 'admin_canal_detail_page.dart';

/// Page admin « Canaux » : liste, filtres (bloqués, bientôt inactifs, mis en avant…) et recherche par nom.
/// Un clic sur un canal ouvre sa fiche de gestion ([AdminCanalDetailPage]).
class AdminCanauxPage extends StatefulWidget {
  const AdminCanauxPage({super.key});

  @override
  State<AdminCanauxPage> createState() => _AdminCanauxPageState();
}

enum _Filter { all, blocked, soon, popular, verified, isPrivate }

class _AdminCanauxPageState extends State<AdminCanauxPage> {
  static const int _pageSize = 30;
  static const int _dayMs = 24 * 60 * 60 * 1000;

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  _Filter _filter = _Filter.all;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String _query = '';
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  List<DocumentSnapshot<Map<String, dynamic>>> _extra = []; // recherche par identifiant

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    final col = FirebaseFirestore.instance.collection('Canaux');
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      return col.orderBy('titre').startAt([q]).endAt(['$q']);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (_filter) {
      case _Filter.blocked:
        return col.where('isBlocked', isEqualTo: true);
      case _Filter.soon:
        return col
            .where('lastPostAt', isGreaterThan: now - 20 * _dayMs)
            .where('lastPostAt', isLessThanOrEqualTo: now - 15 * _dayMs)
            .orderBy('lastPostAt');
      case _Filter.popular:
        return col.where('isPopular', isEqualTo: true);
      case _Filter.verified:
        return col.where('isVerify', isEqualTo: true);
      case _Filter.isPrivate:
        return col.where('isPrivate', isEqualTo: true);
      case _Filter.all:
        return col.orderBy('createdAt', descending: true);
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _docs = [];
        _extra = [];
        _cursor = null;
        _hasMore = false;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      var q = _buildQuery().limit(_pageSize);
      if (!reset && _cursor != null) q = q.startAfterDocument(_cursor!);
      final snap = await q.get();
      // Recherche par identifiant exact (un identifiant de canal fait 20 caractères)
      var extra = <DocumentSnapshot<Map<String, dynamic>>>[];
      if (reset && _query.length >= 15 && !_query.contains(' ')) {
        final byId = await FirebaseFirestore.instance.collection('Canaux').doc(_query).get();
        if (byId.exists) extra = [byId];
      }
      if (!mounted) return;
      setState(() {
        _docs = reset ? snap.docs : [..._docs, ...snap.docs];
        if (reset) _extra = extra;
        if (snap.docs.isNotEmpty) _cursor = snap.docs.last;
        _hasMore = snap.docs.length == _pageSize;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      final q = v.trim();
      if (q == _query) return;
      _query = q;
      _load(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final items = <DocumentSnapshot<Map<String, dynamic>>>[
      ..._extra,
      ..._docs.where((d) => !_extra.any((e) => e.id == d.id)),
    ];
    // Bloqués : les plus récemment bloqués d'abord (tri côté client, pas d'index nécessaire)
    if (_query.isEmpty && _filter == _Filter.blocked) {
      items.sort((a, b) => ((b.data()?['blockedAt'] as num?) ?? 0).compareTo((a.data()?['blockedAt'] as num?) ?? 0));
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Canaux', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => _load(reset: true)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'Rechercher un canal par nom (ou identifiant)',
              hintStyle: TextStyle(color: c.textSecondary),
              prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded, color: c.textSecondary),
                      onPressed: () {
                        _searchCtrl.clear();
                        _query = '';
                        _load(reset: true);
                      },
                    ),
              filled: true,
              fillColor: c.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              _chip(c, 'Tous', _Filter.all),
              _chip(c, 'Bloqués', _Filter.blocked),
              _chip(c, 'Bientôt inactifs (15-20 j)', _Filter.soon),
              _chip(c, 'Mis en avant', _Filter.popular),
              _chip(c, 'Vérifiés', _Filter.verified),
              _chip(c, 'Privés', _Filter.isPrivate),
            ],
          ),
        ),
        if (_query.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Résultats pour « $_query » (les filtres sont ignorés pendant la recherche)',
                  style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? Center(child: Text('Aucun canal', style: TextStyle(color: c.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: items.length + (_hasMore ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == items.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: _loadingMore
                                  ? const CircularProgressIndicator()
                                  : OutlinedButton(onPressed: () => _load(), child: const Text('Charger plus')),
                            ),
                          );
                        }
                        return _CanalTile(doc: items[i]);
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _chip(AppColors c, String label, _Filter f) {
    final selected = _query.isEmpty && _filter == f;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: c.primary,
        backgroundColor: c.surfaceVariant,
        labelStyle: TextStyle(color: selected ? c.onPrimary : c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
        onSelected: (_) {
          _searchCtrl.clear();
          _query = '';
          _filter = f;
          _load(reset: true);
        },
      ),
    );
  }
}

class _CanalTile extends StatelessWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;
  const _CanalTile({required this.doc});

  static const int _dayMs = 24 * 60 * 60 * 1000;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final d = doc.data() ?? {};
    final titre = (d['titre'] ?? '').toString();
    final followers = _followers(d);
    final posts = (d['publication'] as num?)?.toInt() ?? 0;
    final blocked = d['isBlocked'] == true;
    final popularUntil = (d['popularUntil'] as num?)?.toInt() ?? 0;
    final popular = d['isPopular'] == true && (popularUntil == 0 || popularUntil > DateTime.now().millisecondsSinceEpoch);
    final lastPostAt = _ms(d['lastPostAt']);
    final days = lastPostAt > 0 ? ((DateTime.now().millisecondsSinceEpoch - lastPostAt) / _dayMs).floor() : null;

    return Card(
      color: c.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: blocked ? c.danger.withOpacity(0.5) : c.border),
      ),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminCanalDetailPage(canalId: doc.id))),
        leading: SafeNetworkAvatar(url: d['urlImage'] as String?, radius: 22, backgroundColor: c.surfaceVariant, iconColor: c.textSecondary),
        title: Row(children: [
          Flexible(child: NameTag(label: '#$titre', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700))),
          if (d['isVerify'] == true) ...[const SizedBox(width: 4), Icon(Icons.verified_rounded, size: 15, color: c.info)],
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('$followers abonnés · $posts posts${days == null ? '' : ' · dernier post il y a $days j'}',
                style: TextStyle(color: c.textSecondary, fontSize: 12)),
            if (blocked) _badge(c.danger, d['blockReason'] == 'admin' ? 'Bloqué (admin)' : 'Bloqué'),
            if (popular) _badge(c.warning, 'Mis en avant'),
            if (d['isPrivate'] == true) _badge(c.info, 'Privé'),
          ]),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
      ),
    );
  }

  static int _followers(Map<String, dynamic> d) {
    final list = d['usersSuiviId'];
    final n = list is List ? list.length : 0;
    final suivi = (d['suivi'] as num?)?.toInt() ?? 0;
    return n > suivi ? n : suivi;
  }

  static int _ms(dynamic v) {
    final n = (v as num?)?.toInt() ?? 0;
    return n > 100000000000000 ? n ~/ 1000 : n;
  }

  Widget _badge(Color color, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );
}
