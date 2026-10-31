import 'dart:async';

import '../../../services/api/stickers_admin_api.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'admin_sticker_common.dart';
import 'admin_sticker_detail_page.dart';
import 'admin_sticker_pack_page.dart';

/// Administration des stickers : validation des packs, signalements, packs publiés, tous les packs
/// et catalogue complet des stickers.
class AdminStickersPage extends StatelessWidget {
  const AdminStickersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          foregroundColor: c.textPrimary,
          elevation: 0,
          title: const Text('Stickers', style: TextStyle(fontWeight: FontWeight.w700)),
          bottom: TabBar(
            isScrollable: true,
            labelColor: c.primary,
            unselectedLabelColor: c.textSecondary,
            indicatorColor: c.primary,
            tabs: const [
              Tab(text: 'À valider'),
              Tab(text: 'Signalements'),
              Tab(text: 'Publiés'),
              Tab(text: 'Tous'),
              Tab(text: 'Tous les stickers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PacksTab(mode: _PackMode.pending),
            _ReportsTab(),
            _PacksTab(mode: _PackMode.active, searchable: true),
            _PacksTab(mode: _PackMode.all, searchable: true),
            _CatalogTab(),
          ],
        ),
      ),
    );
  }
}

// ── Packs ────────────────────────────────────────────────────────────────────

enum _PackMode { pending, active, all }

class _PacksTab extends StatefulWidget {
  final _PackMode mode;
  final bool searchable;
  const _PacksTab({required this.mode, this.searchable = false});

  @override
  State<_PacksTab> createState() => _PacksTabState();
}

class _PacksTabState extends State<_PacksTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  bool _error = false;
  String _q = '';
  List<StickerDoc> _docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final l = await StickersAdminApi.packs(switch (widget.mode) { _PackMode.pending => 'pending', _PackMode.active => 'active', _PackMode.all => 'all' });
      l.sort((a, b) => ((b.data()['createdAt'] as num?) ?? 0).compareTo((a.data()['createdAt'] as num?) ?? 0));
      if (!mounted) return;
      setState(() {
        _docs = l;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _open(String id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AdminStickerPackPage(packId: id)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    final q = _q.toLowerCase();
    final items = q.isEmpty ? _docs : _docs.where((d) => (d.data()['name'] ?? '').toString().toLowerCase().contains(q)).toList();
    return Column(children: [
      if (widget.searchable)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim()),
            style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'Rechercher un pack par nom',
              hintStyle: TextStyle(color: c.textSecondary),
              prefixIcon: Icon(Icons.search_rounded, color: c.textSecondary),
              filled: true,
              fillColor: c.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
                ? Center(child: TextButton(onPressed: _load, child: const Text('Erreur de chargement, réessayer')))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: items.isEmpty
                        ? ListView(children: [
                            Padding(
                              padding: const EdgeInsets.all(40),
                              child: Center(child: Text('Aucun pack', style: TextStyle(color: c.textSecondary))),
                            ),
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                            itemCount: items.length,
                            itemBuilder: (_, i) => _packTile(c, items[i]),
                          ),
                  ),
      ),
    ]);
  }

  Widget _packTile(AppColors c, StickerDoc d) {
    final p = d.data();
    final status = (p['status'] ?? '').toString();
    final price = (p['priceCoins'] as num?)?.toInt() ?? 0;
    final cover = (p['coverUrl'] ?? '').toString();
    return Card(
      color: c.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p['needsReview'] == true ? c.danger.withOpacity(0.5) : c.border),
      ),
      child: ListTile(
        onTap: () => _open(d.id),
        leading: StickerThumbBox({'thumbUrl': cover}, size: 48),
        title: Text((p['name'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: StickerPseudoText(p['creatorId']?.toString(), style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ),
            Text('${(p['stickerCount'] as num?)?.toInt() ?? 0} stickers · ${price == 0 ? 'gratuit' : '$price pièces'}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            stickerBadge(stickerStatusColor(c, status), stickerStatusLabel(status)),
            if (p['needsReview'] == true) stickerBadge(c.danger, 'Copie possible'),
          ]),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: c.textSecondary),
      ),
    );
  }
}

// ── Signalements ─────────────────────────────────────────────────────────────

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _loading = true;
  bool _error = false;
  List<StickerDoc> _docs = [];
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final l = (await StickersAdminApi.reports())..sort((a, b) => ((b.data()['createdAt'] as num?) ?? 0).compareTo((a.data()['createdAt'] as num?) ?? 0));
      if (!mounted) return;
      setState(() {
        _docs = l;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _close(StickerDoc r, {String resolution = 'dismissed'}) async {
    try {
      await StickersAdminApi.closeReport(r.id, resolution);
      if (mounted) setState(() => _docs = _docs.where((d) => d.id != r.id).toList());
    } catch (e) {
      stickerToast(context, 'Impossible de classer le signalement : $e');
    }
  }

  Future<void> _remove(StickerDoc r) async {
    final id = (r.data()['stickerId'] ?? '').toString();
    if (id.isEmpty) return;
    final reason = await stickerAskReason(context, 'Retirer le sticker');
    if (reason == null || !mounted) return;
    setState(() => _busy.add(r.id));
    final ok = await stickerAdminAction(context, stickerId: id, action: 'remove', reason: reason);
    if (!mounted) return;
    setState(() => _busy.remove(r.id));
    if (ok) {
      stickerToast(context, 'Sticker retiré');
      await _close(r, resolution: 'removed');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error) return Center(child: TextButton(onPressed: _load, child: const Text('Erreur de chargement, réessayer')));
    return RefreshIndicator(
      onRefresh: _load,
      child: _docs.isEmpty
          ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text('Aucun signalement ouvert', style: TextStyle(color: c.textSecondary))))])
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              itemCount: _docs.length,
              itemBuilder: (_, i) => _reportCard(c, _docs[i]),
            ),
    );
  }

  Widget _reportCard(AppColors c, StickerDoc r) {
    final d = r.data();
    final stickerId = (d['stickerId'] ?? '').toString();
    final note = (d['note'] ?? '').toString();
    final busy = _busy.contains(r.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: FutureBuilder<StickerDoc?>(
        future: stickerId.isEmpty ? Future.value(null) : StickersAdminApi.stickerById(stickerId).catchError((_) => null as StickerDoc?),
        builder: (ctx, snap) {
          final s = snap.data?.data();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InkWell(
                onTap: stickerId.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminStickerDetailPage(stickerId: stickerId))),
                child: StickerThumbBox(s ?? const {}, size: 84, animated: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s == null ? 'Sticker introuvable' : (stickerCaption(s).isEmpty ? '(sans légende)' : stickerCaption(s)),
                      style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text('Créateur : ', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                    Flexible(
                      child: InkWell(
                        onTap: () => stickerOpenUser(context, d['creatorId']?.toString()),
                        child: StickerPseudoText(d['creatorId']?.toString(), style: TextStyle(color: c.info, fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ]),
                  Row(children: [
                    Text('Signalé par : ', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                    Flexible(child: StickerPseudoText(d['reporterId']?.toString(), style: TextStyle(color: c.textPrimary, fontSize: 12.5))),
                  ]),
                  Text(stickerDate(d['createdAt']), style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                  if (s != null) ...[
                    const SizedBox(height: 4),
                    stickerBadge(stickerStatusColor(c, (s['status'] ?? '').toString()), stickerStatusLabel((s['status'] ?? '').toString())),
                  ],
                ]),
              ),
            ]),
            if (note.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                child: Text('Note : $note', style: TextStyle(color: c.textPrimary, fontSize: 12.5)),
              ),
            if (s != null && (s['copyOf'] ?? '').toString().isNotEmpty) StickerCompareView(stickerId: stickerId, sticker: s),
            const SizedBox(height: 10),
            if (busy)
              const LinearProgressIndicator()
            else
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (s == null || s['status'] == 'removed') ? null : () => _remove(r),
                    style: ElevatedButton.styleFrom(backgroundColor: c.danger, foregroundColor: Colors.white),
                    child: const Text('Retirer le sticker'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _close(r), child: const Text('Classer sans suite'))),
              ]),
          ]);
        },
      ),
    );
  }
}

// ── Catalogue de tous les stickers ───────────────────────────────────────────

enum _CatFilter { all, active, pending, removed, copies, official }

class _CatalogTab extends StatefulWidget {
  const _CatalogTab();

  @override
  State<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<_CatalogTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const int _pageSize = 30;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  _CatFilter _filter = _CatFilter.all;
  String _query = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _error = false;
  int _page = 1;
  List<StickerDoc> _docs = [];

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

  bool _match(Map<String, dynamic> d) {
    switch (_filter) {
      case _CatFilter.all:
        return true;
      case _CatFilter.active:
        return d['status'] == 'active';
      case _CatFilter.pending:
        return d['status'] == 'pending';
      case _CatFilter.removed:
        return d['status'] == 'rejected' || d['status'] == 'removed';
      case _CatFilter.copies:
        return (d['copyOf'] ?? '').toString().isNotEmpty;
      case _CatFilter.official:
        return d['creatorId'] == 'afrolook';
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = false;
        _docs = [];
        _page = 1;
        _hasMore = false;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final res = await StickersAdminApi.catalog(filter: _filter.name, q: _query, page: reset ? 1 : _page + 1);
      if (!mounted) return;
      if (!reset) _page++;
      setState(() {
        _docs = reset ? res.items : [..._docs, ...res.items];
        _hasMore = res.more;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = true;
      });
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final q = v.trim();
      if (q == _query) return;
      _query = q;
      _load(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = AppColors.of(context);
    const labels = {
      _CatFilter.all: 'Tous',
      _CatFilter.active: 'Actifs',
      _CatFilter.pending: 'En attente',
      _CatFilter.removed: 'Refusés / retirés',
      _CatFilter.copies: 'Copies possibles',
      _CatFilter.official: 'Officiels',
    };
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: TextField(
          controller: _searchCtrl,
          onChanged: _onSearch,
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: 'Identifiant, pack, pseudo du créateur ou légende',
            hintStyle: TextStyle(color: c.textSecondary, fontSize: 13),
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
            for (final f in _CatFilter.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: ChoiceChip(
                  label: Text(labels[f]!),
                  selected: _filter == f,
                  showCheckmark: false,
                  selectedColor: c.primary,
                  backgroundColor: c.surfaceVariant,
                  labelStyle: TextStyle(color: _filter == f ? c.onPrimary : c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                  onSelected: (_) {
                    _filter = f;
                    _load(reset: true);
                  },
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error
                ? Center(child: TextButton(onPressed: () => _load(reset: true), child: const Text('Erreur de chargement, réessayer')))
                : _docs.isEmpty
                    ? Center(child: Text('Aucun sticker', style: TextStyle(color: c.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        itemCount: _docs.length + (_hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == _docs.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: _loadingMore
                                    ? const CircularProgressIndicator()
                                    : OutlinedButton(onPressed: () => _load(), child: const Text('Charger plus')),
                              ),
                            );
                          }
                          return _StickerRow(doc: _docs[i]);
                        },
                      ),
      ),
    ]);
  }
}

class _StickerRow extends StatelessWidget {
  final StickerDoc doc;
  const _StickerRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = doc.data() ?? {};
    final status = (s['status'] ?? '').toString();
    final caption = stickerCaption(s);
    final gift = (s['giftPriceCoins'] as num?)?.toInt() ?? 0;
    final copyOf = (s['copyOf'] ?? '').toString();
    final small = TextStyle(color: c.textSecondary, fontSize: 12);
    return Card(
      color: c.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: copyOf.isNotEmpty ? c.danger.withOpacity(0.5) : c.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminStickerDetailPage(stickerId: doc.id))),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            StickerThumbBox(s, size: 60),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(caption.isEmpty ? '(sans légende)' : caption,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                  stickerBadge(stickerStatusColor(c, status), stickerStatusLabel(status)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Flexible(child: StickerPackNameText(s['packId']?.toString(), style: small)),
                  Text(' · ', style: small),
                  Flexible(child: StickerPseudoText(s['creatorId']?.toString(), style: small)),
                ]),
                Text(
                  'Déposé le ${stickerDate(s['createdAt'])} · ${(s['usageCount'] as num?)?.toInt() ?? 0} util. · ${(s['giftCount'] as num?)?.toInt() ?? 0} cadeaux'
                  '${gift > 0 ? ' · cadeau $gift pièces' : ''}',
                  style: small,
                ),
                if (copyOf.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: c.danger.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Copie possible de ', style: TextStyle(color: c.danger, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 110),
                            child: StickerPseudoText(s['copyOfCreator']?.toString(), style: TextStyle(color: c.danger, fontSize: 10.5, fontWeight: FontWeight.w800)),
                          ),
                        ]),
                      ),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
