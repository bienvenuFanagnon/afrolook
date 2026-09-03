import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';

import '../../../models/model_data.dart';

// ── Palette (même charte que UserManagementPage) ──────────────────────────────
const _bg      = Color(0xFF0D0D14);
const _surface = Color(0xFF16161F);
const _card    = Color(0xFF1C1C27);
const _border  = Color(0xFF2A2A3A);
const _gold    = Color(0xFFF0B429);
const _green   = Color(0xFF34C759);
const _amber   = Color(0xFFFF9F0A);
const _blue    = Color(0xFF3B82F6);
const _purple  = Color(0xFFBF5AF2);
const _teal    = Color(0xFF30B0C7);
const _pink    = Color(0xFFFF2D55);
const _red     = Color(0xFFFF453A);
const _textP   = Color(0xFFE8E8F0);
const _textS   = Color(0xFF8891A6);

// ── Catégorie de filtre ────────────────────────────────────────────────────────
enum _TabFilter { tous, argent, pieces }

class UserTransactionsPage extends StatefulWidget {
  final String userId;
  const UserTransactionsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _UserTransactionsPageState createState() => _UserTransactionsPageState();
}

class _UserTransactionsPageState extends State<UserTransactionsPage>
    with SingleTickerProviderStateMixin {
  final _db             = FirebaseFirestore.instance;
  final _scrollCtrl     = ScrollController();

  UserData? _userData;
  bool _isLoadingUser   = true;
  bool _isLoadingTx     = true;
  bool _isLoadingMore   = false;

  List<TransactionSolde> _allTx       = [];
  List<TransactionSolde> _filteredTx  = [];
  List<TransactionSolde> _displayedTx = [];

  _TabFilter _tab        = _TabFilter.tous;
  String     _typeFilter = 'TOUS';
  DateTime?  _startDate;
  DateTime?  _endDate;

  static const _pageSize = 15;
  int  _page       = 0;
  bool _hasMore    = true;

  // ── Métadonnées par type ───────────────────────────────────────────────────

  static const _meta = {
    // ─ FCFA ─────────────────────────────────────────────────────────────────
    'DEPOT':              _TxMeta('Dépôt',               _green,  Iconsax.arrow_down,        _TabFilter.argent, true),
    'DEPOTADMIN':         _TxMeta('Dépôt Admin',          _green,  Iconsax.arrow_circle_down, _TabFilter.argent, true),
    'RETRAIT':            _TxMeta('Retrait',               _amber,  Iconsax.arrow_up,          _TabFilter.argent, false),
    'RETRAITADMIN':       _TxMeta('Retrait Admin',         _amber,  Iconsax.arrow_circle_up,   _TabFilter.argent, false),
    'GAIN':               _TxMeta('Gain',                  _blue,   Iconsax.chart_2,           _TabFilter.argent, true),
    'DEPENSE':            _TxMeta('Dépense',               _red,    Iconsax.wallet_minus,      _TabFilter.argent, false),
    'ABONNEMENT_OFFICIEL':_TxMeta('Abonnement Officiel',   _purple, Iconsax.star,              _TabFilter.argent, false),
    // ─ Pièces ────────────────────────────────────────────────────────────────
    'GAIN_PIECES':        _TxMeta('Gain pièces',           _gold,   Iconsax.gift,              _TabFilter.pieces, true),
    'LIKE_PIECES':        _TxMeta('Like → Pièces',         _gold,   Iconsax.heart,             _TabFilter.pieces, true),
    'CADEAU_PIECES_RECU': _TxMeta('Cadeau reçu',           _teal,   Iconsax.receive_square,    _TabFilter.pieces, true),
    'CADEAU_PIECES':      _TxMeta('Cadeau envoyé',          _pink,   Iconsax.send_square,       _TabFilter.pieces, false),
    'ACHAT_PIECES':       _TxMeta('Achat pièces',           _purple, Iconsax.buy_crypto,        _TabFilter.pieces, false),
    'CONVERSION_PIECES':  _TxMeta('Conversion pièces',     _teal,   Iconsax.convert_3d_cube,   _TabFilter.pieces, false),
  };

  static _TxMeta _metaFor(String? type) =>
      _meta[type?.toUpperCase()] ??
      const _TxMeta('Inconnu', _textS, Iconsax.transaction_minus, _TabFilter.tous, false);

  static bool _isCoins(String? type) =>
      _meta[type?.toUpperCase()]?.tab == _TabFilter.pieces;

  String _unit(String? type) => _isCoins(type) ? 'pièces' : 'FCFA';
  String _amount(TransactionSolde t) {
    if (_isCoins(t.type)) {
      return '${t.montant?.toInt() ?? 0}';
    }
    return (t.montant ?? 0.0).toStringAsFixed(2);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadUserData();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.offset >= _scrollCtrl.position.maxScrollExtent - 120 &&
        !_isLoadingMore && _hasMore) {
      _loadMore();
    }
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    try {
      final doc = await _db.collection('Users').doc(widget.userId).get();
      if (doc.exists) setState(() => _userData = UserData.fromJson(doc.data()!));
    } catch (e) { printVm('UserTx user load error: $e'); }
    setState(() => _isLoadingUser = false);
    _reload();
  }

  Future<void> _reload() async {
    setState(() { _isLoadingTx = true; _allTx = []; _filteredTx = []; _displayedTx = []; });
    try {
      final snap = await _db
          .collection('TransactionSoldes')
          .where('user_id', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .get();
      _allTx = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return TransactionSolde.fromJson(data);
      }).toList();
    } catch (e) { printVm('UserTx load error: $e'); }
    setState(() => _isLoadingTx = false);
    _applyFilters();
  }

  void _applyFilters() {
    final filtered = _allTx.where((t) {
      if (t.createdAt == null) return false;

      // Onglet
      if (_tab == _TabFilter.argent && _isCoins(t.type)) return false;
      if (_tab == _TabFilter.pieces && !_isCoins(t.type)) return false;

      // Type précis
      if (_typeFilter != 'TOUS' && t.type?.toUpperCase() != _typeFilter) return false;

      // Dates
      final dt = DateTime.fromMillisecondsSinceEpoch(t.createdAt!);
      if (_startDate != null && dt.isBefore(_startDate!)) return false;
      if (_endDate   != null && dt.isAfter(_endDate!.add(const Duration(days: 1)))) return false;

      return true;
    }).toList();

    setState(() {
      _filteredTx = filtered;
      _page       = 0;
      _hasMore    = filtered.length > _pageSize;
      _displayedTx = filtered.take(_pageSize).toList();
    });
  }

  void _loadMore() {
    setState(() => _isLoadingMore = true);
    final next = (_page + 1) * _pageSize;
    if (next >= _filteredTx.length) {
      setState(() { _hasMore = false; _isLoadingMore = false; });
      return;
    }
    final end = (next + _pageSize).clamp(0, _filteredTx.length);
    setState(() {
      _displayedTx.addAll(_filteredTx.sublist(next, end));
      _page++;
      _hasMore = end < _filteredTx.length;
      _isLoadingMore = false;
    });
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(children: [
        _buildUserHeader(),
        _buildTabBar(),
        _buildDateFilters(),
        if (!_isLoadingTx) _buildStats(),
        _buildTypeChips(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      foregroundColor: _textP,
      elevation: 0,
      centerTitle: false,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Transactions',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textP)),
        if (_userData != null)
          Text('@${_userData!.pseudo ?? ''}',
              style: const TextStyle(fontSize: 11, color: _textS, fontWeight: FontWeight.w400)),
      ]),
      actions: [
        IconButton(
          icon: const Icon(Iconsax.refresh, size: 20),
          tooltip: 'Actualiser',
          onPressed: _reload,
        ),
        if (_startDate != null || _endDate != null)
          IconButton(
            icon: const Icon(Icons.clear_rounded, color: _red, size: 20),
            tooltip: 'Effacer les dates',
            onPressed: () {
              setState(() { _startDate = null; _endDate = null; });
              _applyFilters();
            },
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Header utilisateur ────────────────────────────────────────────────────

  Widget _buildUserHeader() {
    if (_isLoadingUser) {
      return Container(
        height: 70, color: _surface,
        child: const Center(child: CircularProgressIndicator(color: _gold, strokeWidth: 2)),
      );
    }
    if (_userData == null) return const SizedBox.shrink();

    final imgUrl = _userData!.imageUrl ?? '';
    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _card,
          backgroundImage: imgUrl.isNotEmpty ? NetworkImage(imgUrl) : null,
          child: imgUrl.isEmpty ? const Icon(Icons.person, color: _textS, size: 22) : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_userData!.pseudo ?? '—',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textP)),
          if ((_userData!.email ?? '').isNotEmpty)
            Text(_userData!.email!, style: const TextStyle(fontSize: 11, color: _textS)),
        ])),
        // Soldes compacts
        _MiniBalance(label: 'Dépôt',  value: '${(_userData!.votre_solde_depot    ?? 0).toStringAsFixed(0)} F', color: _green),
        const SizedBox(width: 8),
        _MiniBalance(label: 'Gains',  value: '${(_userData!.votre_solde_principal ?? 0).toStringAsFixed(0)} F', color: _amber),
        const SizedBox(width: 8),
        _MiniBalance(label: '🪙', value: '${_userData!.giftCoinsBalance ?? 0}', color: _gold),
      ]),
    );
  }

  // ── Tabs Tous / Argent / Pièces ───────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: _surface,
      child: Row(children: [
        for (final t in _TabFilter.values)
          Expanded(child: _TabBtn(
            label: t == _TabFilter.tous ? 'Tous' : t == _TabFilter.argent ? 'Argent' : '🪙 Pièces',
            active: _tab == t,
            onTap: () { setState(() { _tab = t; _typeFilter = 'TOUS'; }); _applyFilters(); },
          )),
      ]),
    );
  }

  // ── Filtres date ──────────────────────────────────────────────────────────

  Widget _buildDateFilters() {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(children: [
        Expanded(child: _DateBtn(
          label: _startDate == null ? 'Depuis' : DateFormat('dd/MM/yy').format(_startDate!),
          active: _startDate != null,
          onTap: () async {
            final p = await showDatePicker(
              context: context, initialDate: DateTime.now(),
              firstDate: DateTime(2023), lastDate: DateTime(2100),
              locale: const Locale('fr', 'FR'),
            );
            if (p != null) { setState(() => _startDate = p); _applyFilters(); }
          },
        )),
        const SizedBox(width: 8),
        Expanded(child: _DateBtn(
          label: _endDate == null ? "Jusqu'à" : DateFormat('dd/MM/yy').format(_endDate!),
          active: _endDate != null,
          onTap: () async {
            final p = await showDatePicker(
              context: context, initialDate: DateTime.now(),
              firstDate: DateTime(2023), lastDate: DateTime(2100),
              locale: const Locale('fr', 'FR'),
            );
            if (p != null) { setState(() => _endDate = p); _applyFilters(); }
          },
        )),
      ]),
    );
  }

  // ── Stats rapides ─────────────────────────────────────────────────────────

  Widget _buildStats() {
    if (_filteredTx.isEmpty) return const SizedBox.shrink();

    double fcfaIn = 0, fcfaOut = 0;
    int coinsIn = 0, coinsOut = 0;

    for (final t in _filteredTx) {
      final m = _metaFor(t.type);
      if (_isCoins(t.type)) {
        final v = (t.montant ?? 0).toInt();
        m.isCredit ? coinsIn  += v : coinsOut += v;
      } else {
        final v = t.montant ?? 0;
        m.isCredit ? fcfaIn  += v : fcfaOut += v;
      }
    }

    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(children: [
        _StatBadge(label: 'Crédits',   value: _fmtFcfa(fcfaIn),   color: _green),
        const SizedBox(width: 8),
        _StatBadge(label: 'Débits',    value: _fmtFcfa(fcfaOut),  color: _amber),
        const SizedBox(width: 8),
        _StatBadge(label: '🪙 Entrées', value: '$coinsIn',         color: _gold),
        const SizedBox(width: 8),
        _StatBadge(label: '🪙 Sorties', value: '$coinsOut',        color: _pink),
      ]),
    );
  }

  // ── Chips filtre par type ─────────────────────────────────────────────────

  Widget _buildTypeChips() {
    final types = ['TOUS', ..._meta.keys.where((k) {
      final t = _meta[k]!.tab;
      if (_tab == _TabFilter.argent && t == _TabFilter.pieces) return false;
      if (_tab == _TabFilter.pieces && t == _TabFilter.argent) return false;
      return true;
    })];

    return Container(
      height: 40,
      color: _bg,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final type = types[i];
          final active = _typeFilter == type;
          final m = type == 'TOUS' ? null : _meta[type];
          final color = m?.color ?? _textS;
          return GestureDetector(
            onTap: () { setState(() => _typeFilter = type); _applyFilters(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active ? color : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? color : color.withOpacity(0.25)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (m != null) ...[Icon(m.icon, size: 12, color: active ? Colors.white : color), const SizedBox(width: 5)],
                Text(
                  type == 'TOUS' ? 'Tous' : (m?.label ?? type),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : color,
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ── Corps liste ───────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_isLoadingTx) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    if (_filteredTx.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Iconsax.receipt, size: 64, color: _border),
        const SizedBox(height: 16),
        const Text('Aucune transaction', style: TextStyle(color: _textP, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          _typeFilter == 'TOUS' ? 'Cet utilisateur n\'a pas encore de transactions'
              : 'Aucune transaction de ce type sur la période',
          style: const TextStyle(color: _textS, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ]));
    }

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${_displayedTx.length} / ${_filteredTx.length} transactions',
              style: const TextStyle(color: _textS, fontSize: 11)),
          Text('Total : ${_filteredTx.length}',
              style: const TextStyle(color: _textS, fontSize: 11)),
        ]),
      ),
      Expanded(
        child: CenteredContent(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
            itemCount: _displayedTx.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _displayedTx.length) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator(color: _gold, strokeWidth: 2)),
                );
              }
              return _TxCard(
                tx: _displayedTx[i],
                meta: _metaFor(_displayedTx[i].type),
                amount: _amount(_displayedTx[i]),
                unit: _unit(_displayedTx[i].type),
                onTap: () => _showDetails(_displayedTx[i]),
              );
            },
          ),
        ),
      ),
    ]);
  }

  // ── Dialog détails ────────────────────────────────────────────────────────

  void _showDetails(TransactionSolde t) {
    final m = _metaFor(t.type);
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => _TxDetailSheet(
          tx: t, meta: m,
          amount: _amount(t), unit: _unit(t.type),
          userData: _userData,
          scrollController: ctrl,
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtFcfa(double v) {
    if (v >= 1000000) return '${(v/1000000).toStringAsFixed(1)}M F';
    if (v >= 1000)    return '${(v/1000).toStringAsFixed(1)}k F';
    return '${v.toStringAsFixed(0)} F';
  }
}

// ── Métadonnées type transaction ──────────────────────────────────────────────

class _TxMeta {
  final String    label;
  final Color     color;
  final IconData  icon;
  final _TabFilter tab;
  final bool      isCredit;
  const _TxMeta(this.label, this.color, this.icon, this.tab, this.isCredit);
}

// ── Composants réutilisables ──────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? _gold : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? _gold : _textS,
          ),
        ),
      ),
    );
  }
}

class _DateBtn extends StatelessWidget {
  final String label;
  final bool   active;
  final VoidCallback onTap;
  const _DateBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _blue.withOpacity(0.1) : _surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _blue : _border),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.calendar_today_rounded, size: 12,
              color: active ? _blue : _textS),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: active ? _blue : _textS,
              fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _MiniBalance extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _MiniBalance({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()])),
      ]),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  const _StatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: _textS, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _TxCard extends StatelessWidget {
  final TransactionSolde tx;
  final _TxMeta  meta;
  final String   amount;
  final String   unit;
  final VoidCallback onTap;
  const _TxCard({
    required this.tx, required this.meta, required this.amount,
    required this.unit, required this.onTap,
  });

  String _fmtDate(int ts) {
    final date = DateTime.fromMillisecondsSinceEpoch(ts);
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yest  = today.subtract(const Duration(days: 1));
    if (date.isAfter(today))  return 'Aujourd\'hui  ${DateFormat('HH:mm').format(date)}';
    if (date.isAfter(yest))   return 'Hier  ${DateFormat('HH:mm').format(date)}';
    return DateFormat('dd MMM yyyy  HH:mm', 'fr').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final color = meta.color;
    final sign  = meta.isCredit ? '+' : '−';
    final signColor = meta.isCredit ? color : _amber;
    final statut = tx.statut?.toUpperCase() ?? '';
    Color statutColor = _textS;
    if (statut == 'VALIDER') statutColor = _green;
    else if (statut == 'ENCOURS') statutColor = _amber;
    else if (statut == 'ANNULER') statutColor = _red;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(children: [
          // Barre de couleur latérale
          Container(
            width: 4,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
            ),
          ),
          // Icône
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(meta.icon, color: color, size: 20),
          ),
          // Contenu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // Badge type
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Text(meta.label,
                        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  if (statut.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: statutColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(statut,
                          style: TextStyle(fontSize: 9, color: statutColor, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: 4),
                if ((tx.description ?? '').isNotEmpty)
                  Text(tx.description!, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _textS)),
                const SizedBox(height: 3),
                Text(_fmtDate(tx.createdAt ?? 0),
                    style: const TextStyle(fontSize: 10, color: _textS)),
              ]),
            ),
          ),
          // Montant
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$sign$amount',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: signColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              Text(unit, style: const TextStyle(fontSize: 10, color: _textS)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Bottom sheet détails ──────────────────────────────────────────────────────

class _TxDetailSheet extends StatelessWidget {
  final TransactionSolde tx;
  final _TxMeta          meta;
  final String           amount;
  final String           unit;
  final UserData?        userData;
  final ScrollController scrollController;

  const _TxDetailSheet({
    required this.tx, required this.meta, required this.amount,
    required this.unit, required this.userData, required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Handle
        Center(
          child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 20),
        // En-tête montant
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: meta.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: meta.color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: meta.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(meta.icon, color: meta.color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(meta.label, style: TextStyle(color: meta.color, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            RichText(text: TextSpan(children: [
              TextSpan(
                text: '${meta.isCredit ? '+' : '−'}$amount',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: meta.color,
                    fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              TextSpan(text: '  $unit',
                  style: const TextStyle(fontSize: 14, color: _textS, fontWeight: FontWeight.w500)),
            ])),
            if ((tx.statut ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              _StatutBadge(tx.statut!),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        // Infos utilisateur
        if (userData != null) ...[
          _SectionTitle('Utilisateur'),
          _Row('Pseudo',    '@${userData!.pseudo ?? '—'}'),
          _Row('E-mail',    userData!.email   ?? '—'),
          if ((userData!.numeroDeTelephone ?? '').isNotEmpty)
            _Row('Téléphone', userData!.numeroDeTelephone!),
          const SizedBox(height: 12),
        ],
        // Infos transaction
        _SectionTitle('Transaction'),
        _Row('Type',        meta.label),
        _Row('Montant',     '$amount $unit'),
        if ((tx.frais ?? 0) > 0)
          _Row('Frais', '${tx.frais!.toStringAsFixed(2)} FCFA'),
        if ((tx.montant_total ?? 0) > 0)
          _Row('Montant total', '${tx.montant_total!.toStringAsFixed(2)} FCFA'),
        if ((tx.description ?? '').isNotEmpty)
          _Row('Description',   tx.description!),
        if ((tx.methode_paiement ?? '').isNotEmpty)
          _Row('Méthode',       tx.methode_paiement!),
        if ((tx.id_transaction_cinetpay ?? '').isNotEmpty)
          _Row('ID CinetPay',   tx.id_transaction_cinetpay!),
        if ((tx.numero_depot ?? '').isNotEmpty)
          _Row('N° dépôt',      tx.numero_depot!),
        _Row('Date',
            tx.createdAt != null
                ? DateFormat('dd MMM yyyy  HH:mm:ss', 'fr')
                    .format(DateTime.fromMillisecondsSinceEpoch(tx.createdAt!))
                : '—'),
        if ((tx.id ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () { Clipboard.setData(ClipboardData(text: tx.id!)); },
            child: _Row('ID', tx.id!, mono: true, tapLabel: 'Copier'),
          ),
        ],
      ],
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final String statut;
  const _StatutBadge(this.statut);

  @override
  Widget build(BuildContext context) {
    Color c = _textS;
    if (statut.toUpperCase() == 'VALIDER') c = _green;
    else if (statut.toUpperCase() == 'ENCOURS') c = _amber;
    else if (statut.toUpperCase() == 'ANNULER') c = _red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(statut, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text.toUpperCase(),
          style: const TextStyle(fontSize: 10, color: _textS,
              fontWeight: FontWeight.w700, letterSpacing: 1.4)),
    );
  }
}

class _Row extends StatelessWidget {
  final String  label;
  final String  value;
  final bool    mono;
  final String? tapLabel;
  const _Row(this.label, this.value, {this.mono = false, this.tapLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: _textS, fontWeight: FontWeight.w500))),
        Expanded(
          child: Row(children: [
            Expanded(
              child: Text(value,
                  style: TextStyle(fontSize: 13, color: _textP,
                      fontFamily: mono ? 'monospace' : null),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            if (tapLabel != null) ...[
              const SizedBox(width: 8),
              Text(tapLabel!, style: const TextStyle(fontSize: 11, color: _blue)),
            ],
          ]),
        ),
      ]),
    );
  }
}
