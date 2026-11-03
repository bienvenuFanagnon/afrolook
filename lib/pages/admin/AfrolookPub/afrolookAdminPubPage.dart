// afrolookAdminPubPage.dart — hub « Publicité » de l'administration, via l'API.
// Mêmes fonctions que l'ancien écran d'avant la migration : boosts payants des utilisateurs (publication, profil, canal, groupe) par statut et par type,
// chiffres, accepter, rejeter AVEC remboursement des pièces, annuler, réactiver, prolonger gratuitement, supprimer, bouton d'action, tarifs, statistiques.
// L'onglet « Régie » garde la file des annonces des annonceurs du site (Afrolook Ads).
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/canaux/detailsCanal.dart';
import 'package:afrotok/pages/chat/group/group_chat_page.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/postDetailsVideo.dart';
import 'package:afrotok/pages/pub/ad_route_picker.dart';
import 'package:afrotok/pages/user/otherUser/otherUser.dart';
import 'package:afrotok/services/ad_config_service.dart';
import 'package:afrotok/services/api/canaux_api.dart';
import 'package:afrotok/services/api/posts_api.dart';
import 'package:afrotok/services/api/regie_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class AdvertisementManagementPage extends StatefulWidget {
  const AdvertisementManagementPage({Key? key}) : super(key: key);

  @override
  State<AdvertisementManagementPage> createState() => _AdvertisementManagementPageState();
}

class _AdvertisementManagementPageState extends State<AdvertisementManagementPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 7, vsync: this);
  final TextEditingController _search = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic> _stats = {};
  String _typeFilter = 'all';
  String _query = '';

  // file de la régie (annonces des annonceurs)
  bool _regieLoading = true;
  String? _regieError;
  List<Map<String, dynamic>> _regie = [];

  static const _statusTabs = ['pending', 'active', 'expired', 'rejected', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() => _query = _search.text.toLowerCase().trim()));
    _load();
    _loadRegie();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  // ── Données ─────────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await RegieApi.getMap('/admin/ads/boosts', query: {'status': 'all'});
      if (!mounted) return;
      setState(() {
        _items = ((r['items'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _stats = r['stats'] is Map ? Map<String, dynamic>.from(r['stats'] as Map) : {};
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = RegieApi.err(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadRegie() async {
    setState(() {
      _regieLoading = true;
      _regieError = null;
    });
    try {
      final q = await RegieApi.getMap('/admin/ads/queue');
      if (!mounted) return;
      setState(() {
        _regie = ((q['ads'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _regieLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _regieError = RegieApi.err(e);
          _regieLoading = false;
        });
      }
    }
  }

  void _toast(String m, {bool error = false}) {
    if (!mounted) return;
    final c = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: error ? c.danger : c.primary));
  }

  Future<bool> _run(Future<dynamic> Function() action, String ok) async {
    try {
      await action();
      _toast(ok);
      await _load();
      return true;
    } catch (e) {
      _toast(RegieApi.err(e), error: true);
      return false;
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _decide(Map<String, dynamic> ad, String action, String ok, {String? reason}) async {
    await _run(() => RegieApi.post('/admin/ads/boosts/${ad['id']}/decision', body: {'action': action, if (reason != null) 'reason': reason}), ok);
  }

  Future<void> _rejectDialog(Map<String, dynamic> ad) async {
    final c = AppColors.of(context);
    final ctl = TextEditingController();
    final refundable = ad['status'] == 'pending';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.warning_amber, color: c.danger, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text('Rejeter la publicité', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Indiquez le motif (obligatoire)', style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: ctl,
            maxLines: 3,
            maxLength: 200,
            style: TextStyle(color: c.textPrimary),
            decoration: InputDecoration(hintText: 'Motif…', hintStyle: TextStyle(color: c.textSecondary), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), filled: true, fillColor: c.surfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            refundable ? 'La personne sera remboursée de ${_n(ad['coins'])} pièces (${_n(ad['priceXof'])} FCFA).' : 'Annonce déjà diffusée : aucun remboursement.',
            style: TextStyle(color: refundable ? c.accentText : c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: c.textSecondary))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: c.danger, foregroundColor: Colors.white),
            child: Text(refundable ? 'Rejeter et rembourser' : 'Rejeter'),
          ),
        ],
      ),
    );
    final reason = ctl.text.trim();
    if (ok != true) return;
    if (reason.length < 3) {
      _toast('Le motif est obligatoire.', error: true);
      return;
    }
    await _decide(ad, 'reject', refundable ? 'Publicité rejetée, pièces remboursées' : 'Publicité rejetée', reason: reason);
  }

  Future<void> _extendDialog(Map<String, dynamic> ad) async {
    final c = AppColors.of(context);
    const options = {7: '7 jours', 14: '14 jours', 30: '1 mois', 60: '2 mois', 90: '3 mois'};
    int? picked;
    final days = await showDialog<int>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Prolonger la publicité', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Durée de prolongation (gratuit — équipe)', style: TextStyle(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in options.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: picked == e.key,
                  onSelected: (_) => setD(() => picked = e.key),
                  selectedColor: c.primary.withOpacity(0.18),
                  labelStyle: TextStyle(color: picked == e.key ? c.primary : c.textPrimary, fontWeight: picked == e.key ? FontWeight.bold : FontWeight.normal),
                  side: BorderSide(color: picked == e.key ? c.primary : c.border),
                ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: c.textSecondary))),
            FilledButton(onPressed: picked == null ? null : () => Navigator.pop(ctx, picked), child: const Text('Prolonger')),
          ],
        ),
      ),
    );
    if (days == null) return;
    await _run(() => RegieApi.post('/admin/ads/boosts/${ad['id']}/extend', body: {'days': days}), 'Publicité prolongée de $days jours');
  }

  Future<void> _deleteDialog(Map<String, dynamic> ad) async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Supprimer cette publicité ?', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Action irréversible. Seule la publicité est supprimée : l\'élément relié (post, profil, canal ou groupe) reste en place. Aucun remboursement.', style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: c.textSecondary))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: c.danger, foregroundColor: Colors.white), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => RegieApi.delete('/admin/ads/boosts/${ad['id']}'), 'Publicité supprimée');
  }

  Future<void> _editCta(Map<String, dynamic> ad) async {
    final r = await showAdRoutePicker(context, currentUrl: ad['actionUrl'] as String?, currentLabel: ad['actionText'] as String?);
    if (r == null) return;
    await _run(() => RegieApi.patch('/admin/ads/boosts/${ad['id']}/action', body: {'action_text': r['actionButtonText'], 'action_url': r['actionUrl']}), 'Bouton d\'action mis à jour');
  }

  Future<void> _openEntity(Map<String, dynamic> ad) async {
    try {
      final type = '${ad['type']}';
      final id = '${ad['targetId'] ?? ''}';
      if (type == 'new' || (type != 'post' && id.isEmpty)) {
        _toast('Annonce autonome : aucun élément relié.');
        return;
      }
      if (type == 'canal') {
        final canal = await CanauxApi.get(id);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: canal)));
      } else if (type == 'group') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatPage(groupId: id, groupName: '${ad['name'] ?? 'Groupe'}', groupImageUrl: '${ad['avatar'] ?? ''}')));
      } else if (type == 'profile') {
        final u = userFromApi(await UsersApi.publicProfile(id));
        u.id ??= id;
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserPage(otherUser: u)));
      } else {
        final post = await PostsApi.get('${ad['postId'] ?? id}');
        if (post == null || !mounted) {
          _toast('Publication introuvable.', error: true);
          return;
        }
        final video = post.dataType == PostDataType.VIDEO.name;
        Navigator.push(context, MaterialPageRoute(builder: (_) => video ? VideoYoutubePageDetails(initialPost: post) : DetailsPost(post: post)));
      }
    } catch (e) {
      _toast('Impossible d\'ouvrir : ${RegieApi.err(e)}', error: true);
    }
  }

  Future<void> _tariffs() async {
    final c = AppColors.of(context);
    List<Map<String, dynamic>> current;
    try {
      final r = await RegieApi.getMap('/admin/ads/boost-pricing');
      current = ((r['durations'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      _toast(RegieApi.err(e), error: true);
      return;
    }
    if (!mounted) return;
    final ctls = {for (final d in current) '${d['weeks']}': TextEditingController(text: '${d['price']}')};
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.price_change_outlined, color: c.accentText, size: 22),
          const SizedBox(width: 10),
          Text('Tarifs publicités', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Modifiez les tarifs (FCFA). Ils s\'appliquent aux prochains boosts.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            const SizedBox(height: 14),
            for (final d in current)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
                child: Row(children: [
                  Expanded(
                    flex: 2,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${d['label']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${d['weeks']} sem.', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                    ]),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: ctls['${d['weeks']}'],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.right,
                      style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(suffixText: 'FCFA', isDense: true, filled: true, fillColor: c.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: TextStyle(color: c.textSecondary))),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.save, size: 16), label: const Text('Enregistrer')),
        ],
      ),
    );
    if (save != true) return;
    try {
      final durations = [for (final d in current) {'weeks': d['weeks'], 'label': d['label'], 'price': int.tryParse(ctls['${d['weeks']}']!.text) ?? d['price']}];
      await RegieApi.put('/admin/ads/boost-pricing', body: {'durations': durations});
      AdConfigService.invalidateCache();
      _toast('Tarifs mis à jour');
    } catch (e) {
      _toast(RegieApi.err(e), error: true);
    }
  }

  // ── Helpers d'affichage ─────────────────────────────────────────────────────

  static String _n(Object? v) {
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}K';
    return NumberFormat.decimalPattern('fr').format(n);
  }

  static DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

  static String _day(Object? v) {
    final d = _date(v);
    return d == null ? '—' : DateFormat('dd/MM/yy').format(d);
  }

  String _typeLabel(String t) => const {'post': 'Post', 'profile': 'Profil', 'canal': 'Canal', 'group': 'Groupe', 'new': 'Annonce'}[t] ?? 'Post';

  IconData _typeIcon(String t, {bool video = false}) => switch (t) {
        'canal' => Icons.wifi_tethering,
        'group' => Icons.groups_2_outlined,
        'profile' => Icons.person_outline,
        'new' => Icons.campaign_outlined,
        _ => video ? Icons.videocam_outlined : Icons.image_outlined,
      };

  Color _typeColor(AppColors c, String t) => switch (t) {
        'canal' => c.info,
        'group' => c.warning,
        'profile' => c.primary,
        'new' => c.textSecondary,
        _ => c.accentText,
      };

  String _statusLabel(String s) => const {'active': 'Active', 'pending': 'En attente', 'expired': 'Expirée', 'rejected': 'Rejetée', 'cancelled': 'Annulée'}[s] ?? s;

  Color _statusColor(AppColors c, String s) => switch (s) {
        'active' => c.primary,
        'pending' => c.warning,
        'rejected' => c.danger,
        _ => c.textSecondary,
      };

  List<Map<String, dynamic>> _visible(String status) => _items.where((a) {
        if (a['status'] != status) return false;
        if (_typeFilter != 'all' && a['type'] != (_typeFilter == 'profil' ? 'profile' : _typeFilter == 'groupe' ? 'group' : _typeFilter)) return false;
        if (_query.isEmpty) return true;
        return ('${a['name']} ${a['ownerName']} ${a['ownerUsername']} ${a['id']} ${a['ownerId']}').toLowerCase().contains(_query);
      }).toList();

  // ── Interface ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    int count(String s) => (_stats[s] as num?)?.toInt() ?? 0;
    Widget tab(String label, int n, {bool alert = false}) => Tab(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label),
            if (n > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: alert ? c.badgeFill : c.surfaceVariant, borderRadius: BorderRadius.circular(10)),
                child: Text('$n', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: alert ? c.onBadge : c.textSecondary)),
              ),
            ],
          ]),
        );
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Publicité'),
        actions: [
          IconButton(tooltip: 'Tarifs publicités', icon: const Icon(Icons.price_change_outlined), onPressed: _tariffs),
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _load();
              _loadRegie();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: c.primary,
          unselectedLabelColor: c.textSecondary,
          indicatorColor: c.primary,
          tabs: [
            tab('En attente', count('pending'), alert: true),
            tab('Actives', count('active')),
            tab('Expirées', count('expired')),
            tab('Rejetées', count('rejected')),
            tab('Annulées', count('cancelled')),
            const Tab(text: 'Stats'),
            tab('Régie', _regie.length, alert: true),
          ],
        ),
      ),
      body: SafeArea(
        child: CenteredContent(
          maxWidth: 900,
          child: TabBarView(controller: _tabs, children: [
            for (final s in _statusTabs) _statusTab(c, s),
            _statsTab(c),
            _regieTab(c),
          ]),
        ),
      ),
    );
  }

  Widget _statusTab(AppColors c, String status) {
    Widget body() {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) return _retry(c, _error!, _load);
      final list = _visible(status);
      if (list.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.campaign_outlined, size: 48, color: c.textSecondary),
            const SizedBox(height: 12),
            Text('Aucune publicité ${_statusLabel(status).toLowerCase()}', style: TextStyle(color: c.textSecondary, fontSize: 14)),
          ]),
        );
      }
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _row(c, list[i]),
        ),
      );
    }

    return Column(children: [_kpiRow(c), _toolbar(c), Expanded(child: body())]);
  }

  Widget _retry(AppColors c, String message, VoidCallback onRetry) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: c.danger)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Réessayer')),
          ]),
        ),
      );

  Widget _kpiRow(AppColors c) {
    if (_loading) return const SizedBox(height: 4);
    Widget card(IconData icon, String label, String value, Color color, {bool highlight = false}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: highlight ? color.withOpacity(0.6) : c.border, width: highlight ? 1.5 : 0.8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 4),
                Expanded(child: Text(label, style: TextStyle(color: c.textSecondary, fontSize: 10.5), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 5),
              Text(value, style: TextStyle(color: highlight ? color : c.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
          ),
        );
    final pending = (_stats['pending'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(children: [
        card(Icons.hourglass_empty, 'En attente', '$pending', c.warning, highlight: pending > 0),
        const SizedBox(width: 8),
        card(Icons.check_circle_outline, 'Actives', '${_stats['active'] ?? 0}', c.primary),
        const SizedBox(width: 8),
        card(Icons.remove_red_eye_outlined, 'Vues', _n(_stats['views']), c.info),
        const SizedBox(width: 8),
        card(Icons.monetization_on_outlined, 'Revenus', '${_n(_stats['revenueXof'])} F', c.accentText),
      ]),
    );
  }

  Widget _toolbar(AppColors c) {
    Widget chip(String value, String label, IconData icon, Color color) {
      final sel = _typeFilter == value;
      return GestureDetector(
        onTap: () => setState(() => _typeFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.12) : c.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? color.withOpacity(0.55) : c.border, width: sel ? 1.5 : 0.8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: sel ? color : c.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11.5, color: sel ? color : c.textSecondary, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 40,
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
          child: Row(children: [
            const SizedBox(width: 12),
            Icon(Icons.search, color: c.textSecondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _search,
                style: TextStyle(color: c.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(hintText: 'Rechercher par nom, pseudo, ID…', hintStyle: TextStyle(color: c.textSecondary, fontSize: 13.5), border: InputBorder.none, isDense: true),
              ),
            ),
            if (_query.isNotEmpty) IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.close, size: 16, color: c.textSecondary), onPressed: _search.clear),
          ]),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip('all', 'Tous', Icons.grid_view, c.textPrimary),
            const SizedBox(width: 6),
            chip('post', 'Post', Icons.image_outlined, c.accentText),
            const SizedBox(width: 6),
            chip('canal', 'Canal', Icons.wifi_tethering, c.info),
            const SizedBox(width: 6),
            chip('profil', 'Profil', Icons.person_outline, c.primary),
            const SizedBox(width: 6),
            chip('groupe', 'Groupe', Icons.groups_2_outlined, c.warning),
          ]),
        ),
      ]),
    );
  }

  Widget _avatar(AppColors c, Map<String, dynamic> a, {double size = 44}) {
    final type = '${a['type']}';
    final url = '${a['avatar'] ?? ''}';
    final color = _typeColor(c, type);
    final fallback = Container(color: color.withOpacity(0.15), child: Icon(_typeIcon(type, video: a['video'] == true), size: size * 0.5, color: color));
    return ClipRRect(
      borderRadius: BorderRadius.circular(type == 'canal' || type == 'group' ? 10 : size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty ? fallback : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, errorWidget: (_, __, ___) => fallback),
      ),
    );
  }

  Widget _badge(AppColors c, String status) {
    final color = _statusColor(c, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(20)),
      child: Text(_statusLabel(status), style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _row(AppColors c, Map<String, dynamic> a) {
    final type = '${a['type']}';
    final color = _typeColor(c, type);
    final followers = (a['followers'] as num?)?.toInt() ?? 0;
    final coins = (a['coins'] as num?)?.toInt() ?? 0;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _detail(a),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Row(children: [
          _avatar(c, a),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_typeIcon(type, video: a['video'] == true), size: 12, color: color),
                const SizedBox(width: 4),
                Text(_typeLabel(type), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(_day(a['createdAt']), style: TextStyle(fontSize: 11, color: c.textSecondary)),
              ]),
              const SizedBox(height: 3),
              Text('${a['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(
                [
                  if ((a['ownerName'] ?? '').toString().isNotEmpty) 'par ${a['ownerName']}',
                  if (followers > 0) '${_n(followers)} ${type == 'group' ? 'membres' : 'abonnés'}',
                  if (coins > 0) '${_n(a['priceXof'])} FCFA · ${a['days']} j',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: c.textSecondary),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _badge(c, '${a['status']}'),
            const SizedBox(height: 6),
            Icon(Icons.chevron_right, size: 18, color: c.textSecondary),
          ]),
        ]),
      ),
    );
  }

  // ── Détail et actions ───────────────────────────────────────────────────────

  void _detail(Map<String, dynamic> a) {
    final c = AppColors.of(context);
    final type = '${a['type']}';
    final color = _typeColor(c, type);
    final status = '${a['status']}';
    final start = _date(a['startsAt']);
    final end = _date(a['endsAt']);
    final now = DateTime.now();
    final totalDays = (a['days'] as num?)?.toInt() ?? 0;
    final remaining = end == null ? 0 : (end.difference(now).inHours / 24).ceil();
    final progress = (start != null && end != null && end.isAfter(start)) ? (now.difference(start).inSeconds / end.difference(start).inSeconds).clamp(0.0, 1.0) : (status == 'expired' ? 1.0 : 0.0);
    final countries = ((a['countries'] as List?) ?? const []).map((e) => '$e').toList();
    final followers = (a['followers'] as num?)?.toInt() ?? 0;
    final description = '${a['description'] ?? ''}';
    final reason = '${a['rejectReason'] ?? ''}';
    final url = '${a['actionUrl'] ?? ''}';
    final coins = (a['coins'] as num?)?.toInt() ?? 0;

    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border, width: 0.6)),
            child: Column(children: [
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
              Text(label, style: TextStyle(fontSize: 10.5, color: c.textSecondary)),
            ]),
          ),
        );

    Widget btn(String label, Color col, IconData icon, VoidCallback onTap, {bool outlined = false}) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.pop(context);
              onTap();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(color: outlined ? Colors.transparent : col.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: outlined ? c.border : col.withOpacity(0.45))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 16, color: col),
                const SizedBox(width: 6),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: col))),
              ]),
            ),
          ),
        );

    Widget pair(Widget l, Widget r) => Row(children: [l, const SizedBox(width: 10), r]);

    final Widget mainActions;
    if (status == 'pending') {
      mainActions = pair(btn('Accepter', c.primary, Icons.check, () => _decide(a, 'approve', 'Publicité activée')), btn('Rejeter', c.danger, Icons.close, () => _rejectDialog(a)));
    } else if (status == 'active') {
      mainActions = pair(btn('Annuler', c.danger, Icons.block_outlined, () => _decide(a, 'cancel', 'Publicité annulée')), btn('Prolonger', c.accentText, Icons.update, () => _extendDialog(a)));
    } else if (status == 'expired' || status == 'cancelled') {
      mainActions = pair(btn('Réactiver', c.primary, Icons.play_circle_outline, () => _decide(a, 'reactivate', 'Publicité réactivée')), btn('Prolonger', c.accentText, Icons.update, () => _extendDialog(a)));
    } else {
      mainActions = Row(children: [btn('Remettre en attente', c.warning, Icons.refresh, () => _decide(a, 'pending', 'Publicité remise en attente'))]);
    }

    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(22)), border: Border(top: BorderSide(color: color.withOpacity(0.45), width: 2))),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                _avatar(c, a, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${a['name'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
                    const SizedBox(height: 5),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withOpacity(0.13), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_typeIcon(type, video: a['video'] == true), size: 11, color: color),
                          const SizedBox(width: 3),
                          Text(_typeLabel(type), style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                      const SizedBox(width: 6),
                      _badge(c, status),
                    ]),
                    if ((a['ownerName'] ?? '').toString().isNotEmpty || followers > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if ((a['ownerName'] ?? '').toString().isNotEmpty) 'Demandée par ${a['ownerName']}${(a['ownerUsername'] ?? '').toString().isNotEmpty ? ' (@${a['ownerUsername']})' : ''}',
                          if (followers > 0) '${_n(followers)} ${type == 'group' ? 'membres' : 'abonnés'}',
                        ].join(' · '),
                        style: TextStyle(fontSize: 11.5, color: c.textSecondary),
                      ),
                    ],
                  ]),
                ),
                if (coins > 0)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${_n(a['priceXof'])} FCFA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.accentText)),
                    Text('${_n(coins)} pièces', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                    Text('$totalDays jours', style: TextStyle(fontSize: 11, color: c.textSecondary)),
                  ]),
              ]),
              const SizedBox(height: 16),
              if (start != null || end != null) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_day(a['startsAt']), style: TextStyle(fontSize: 10.5, color: c.textSecondary)),
                  Text(status == 'active' && remaining > 0 ? '$remaining j restants' : (status == 'pending' ? 'Pas encore démarrée' : 'Terminée'), style: TextStyle(fontSize: 10.5, color: c.textSecondary, fontWeight: FontWeight.w600)),
                  Text(_day(a['endsAt']), style: TextStyle(fontSize: 10.5, color: c.textSecondary)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: progress, minHeight: 6, backgroundColor: c.border, valueColor: AlwaysStoppedAnimation(color))),
                const SizedBox(height: 14),
              ],
              Row(children: [
                stat(_n(a['views']), 'Vues'),
                const SizedBox(width: 8),
                stat(_n(a['clicks']), 'Clics'),
                const SizedBox(width: 8),
                stat('${a['ctr'] ?? 0}%', 'CTR'),
                const SizedBox(width: 8),
                stat(_n(a['uniqueViews']), 'Uniques'),
              ]),
              const SizedBox(height: 14),
              if (countries.isNotEmpty && !countries.contains('ALL')) ...[
                Text('Pays ciblés', style: TextStyle(fontSize: 11.5, color: c.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(spacing: 4, runSpacing: 4, children: [
                  for (final k in countries.take(8))
                    Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(5), border: Border.all(color: c.border, width: 0.6)), child: Text(k, style: TextStyle(fontSize: 11, color: c.textSecondary))),
                  if (countries.length > 8) Padding(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), child: Text('+${countries.length - 8}', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 14),
              ] else ...[
                Row(children: [Icon(Icons.public, size: 14, color: c.textSecondary), const SizedBox(width: 5), Text('Tous les pays', style: TextStyle(fontSize: 11.5, color: c.textSecondary))]),
                const SizedBox(height: 14),
              ],
              if (description.isNotEmpty) ...[
                Text('Description', style: TextStyle(fontSize: 11.5, color: c.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(description, maxLines: 5, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: c.textPrimary, height: 1.5)),
                const SizedBox(height: 14),
              ],
              if (url.isNotEmpty) ...[
                InkWell(
                  onTap: () => url.startsWith('https://') ? launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) : Clipboard.setData(ClipboardData(text: url)),
                  child: Text('${a['actionText'] ?? 'Bouton'} → $url', style: TextStyle(fontSize: 12.5, color: c.info, decoration: TextDecoration.underline)),
                ),
                const SizedBox(height: 14),
              ],
              if (reason.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.danger.withOpacity(0.3), width: 0.6)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Motif du rejet', style: TextStyle(fontSize: 10.5, color: c.danger, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(reason, style: TextStyle(fontSize: 12.5, color: c.danger)),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              Divider(height: 1, color: c.border),
              const SizedBox(height: 14),
              mainActions,
              const SizedBox(height: 10),
              pair(btn('Supprimer', c.textSecondary, Icons.delete_outline, () => _deleteDialog(a), outlined: true), btn('Voir ${_typeLabel(type).toLowerCase()}', color, Icons.open_in_new, () => _openEntity(a))),
              const SizedBox(height: 10),
              Row(children: [btn('Modifier le bouton d\'action', c.info, Icons.touch_app_outlined, () => _editCta(a))]),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Statistiques ────────────────────────────────────────────────────────────

  Widget _statsTab(AppColors c) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _retry(c, _error!, _load);
    Widget metric(IconData icon, String label, String value, Color color) => Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.textPrimary)),
            Text(label, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
          ]),
        );
    Widget ranking(String title, List top, Color color) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
            const SizedBox(height: 8),
            if (top.isEmpty) Text('Rien pour l\'instant', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
            for (var i = 0; i < top.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 22, child: Text('${i + 1}.', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.bold))),
                  Expanded(child: Text('${(top[i] as Map)['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 13))),
                  Text(_n((top[i] as Map)['value']), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ]),
              ),
          ]),
        );
    final daily = (_stats['daily'] is Map) ? Map<String, dynamic>.from(_stats['daily'] as Map) : <String, dynamic>{};
    final days = daily.keys.toList()..sort();
    final peak = days.fold<int>(1, (m, d) => ((daily[d] as num).toInt() > m) ? (daily[d] as num).toInt() : m);
    return ListView(padding: const EdgeInsets.all(14), children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        metric(Icons.campaign_outlined, 'Publicités', _n(_stats['total']), c.primary),
        metric(Icons.remove_red_eye_outlined, 'Vues', _n(_stats['views']), c.info),
        metric(Icons.groups_outlined, 'Vues uniques', _n(_stats['uniqueViews']), c.info),
        metric(Icons.ads_click, 'Clics', _n(_stats['clicks']), c.warning),
        metric(Icons.percent, 'Taux de clic', '${_stats['ctr'] ?? 0} %', c.primary),
        metric(Icons.monetization_on_outlined, 'Revenus', '${_n(_stats['revenueXof'])} F', c.accentText),
      ]),
      const SizedBox(height: 14),
      ranking('Top 5 — Vues', (_stats['topViews'] as List?) ?? const [], c.info),
      const SizedBox(height: 10),
      ranking('Top 5 — Clics', (_stats['topClicks'] as List?) ?? const [], c.warning),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Activité récente (vues par jour)', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
          const SizedBox(height: 12),
          if (days.isEmpty) Text('Aucune activité', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          if (days.isNotEmpty)
            SizedBox(
              height: 90,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final d in days)
                  Expanded(
                    child: Tooltip(
                      message: '$d : ${daily[d]} vues',
                      child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: 6 + 84 * ((daily[d] as num).toInt() / peak), decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(3))),
                    ),
                  ),
              ]),
            ),
        ]),
      ),
    ]);
  }

  // ── Régie : annonces des annonceurs du site ────────────────────────────────

  Future<void> _decideRegie(Map<String, dynamic> ad, String action) async {
    String? reason;
    if (action == 'reject') {
      final ctl = TextEditingController();
      final c = AppColors.of(context);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: c.surface,
          title: const Text('Refuser cette annonce'),
          content: TextField(controller: ctl, maxLines: 3, decoration: const InputDecoration(hintText: 'Motif (obligatoire, 5 caractères au moins)')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Refuser')),
          ],
        ),
      );
      if (ok != true) return;
      reason = ctl.text.trim();
      if (reason.length < 5) {
        _toast('Le motif doit faire 5 caractères au moins.', error: true);
        return;
      }
    }
    try {
      await RegieApi.post('/admin/ads/decisions', body: {'type': 'ad', 'id': '${ad['id']}', 'action': action, if (reason != null) 'reason': reason});
      _toast(action == 'approve' ? 'Annonce validée' : 'Annonce refusée');
      _loadRegie();
    } catch (e) {
      _toast(RegieApi.err(e), error: true);
    }
  }

  Widget _regieTab(AppColors c) {
    if (_regieLoading) return const Center(child: CircularProgressIndicator());
    if (_regieError != null) return _retry(c, _regieError!, _loadRegie);
    if (_regie.isEmpty) return Center(child: Text('Aucune annonce de la régie en attente.', style: TextStyle(color: c.textSecondary)));
    return RefreshIndicator(
      onRefresh: _loadRegie,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _regie.length,
        itemBuilder: (_, i) {
          final ad = _regie[i];
          final img = '${ad['thumb_url'] ?? ad['media_url'] ?? ''}';
          final url = '${ad['action_url'] ?? ''}';
          return Card(
            color: c.surface,
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (img.startsWith('http'))
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(img, height: 160, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(height: 60, child: Icon(Icons.broken_image_outlined)))),
                const SizedBox(height: 8),
                Text('${ad['title'] ?? ''}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
                if ('${ad['text'] ?? ''}'.isNotEmpty) Text('${ad['text']}', style: TextStyle(color: c.textSecondary)),
                const SizedBox(height: 4),
                Text('Catégorie : ${ad['category'] ?? '—'} · ${ad['paid'] == true ? 'payante' : 'gratuite'}${ad['network'] == true ? ' · offre Réseau' : ''}', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                if (url.startsWith('http'))
                  InkWell(onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication), child: Padding(padding: const EdgeInsets.only(top: 4), child: Text(url, style: TextStyle(color: c.info, decoration: TextDecoration.underline, fontSize: 13)))),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  FilledButton(onPressed: () => _decideRegie(ad, 'approve'), child: const Text('Valider')),
                  OutlinedButton(onPressed: () => _decideRegie(ad, 'reject'), child: const Text('Refuser')),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }
}
