import 'certifications_admin_page.dart';
import '../liveshop/live_shop_admin_page.dart';
import 'seller_verifications_admin_page.dart';
import 'app_version_admin_page.dart';
import 'package:afrotok/services/api/regie_api.dart';
import 'contes_admin_page.dart';
import 'etude_admin_page.dart';
import 'package:afrotok/layout/centered_content.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../contenuPayant/admin_content_page.dart';
import '../user/profile/adminprofil.dart';
import '../user/profile/retraitAdmin/retraitAdminList.dart';
import '../user/profile/retraitAdmin/searchUserAdmin.dart';
import '../weekly_top/weekly_top_commentators_page.dart';
import 'AfrolookPub/afrolookAdminPubPage.dart';
import 'emails_admin_page.dart';
import 'work_stats_page.dart';
import 'afrolook_group_migration_page.dart';
import 'ad_admin_page.dart';
import 'admin_canaux_page.dart';
import 'admin_groups_page.dart';
import 'ads_regie_admin_page.dart';
import 'admin_email_screen.dart';
import 'commissions_admin_page.dart';
import 'influencer_requests_page.dart';
import 'moderation_reports_page.dart';
import 'news_admin_page.dart';
import 'official_accounts_page.dart';
import 'payment_methods_admin_page.dart';
import 'payment_logs_admin_page.dart';
import 'remuneration_admin_page.dart';
import 'quiz_admin_page.dart';
import 'stickers/admin_stickers_page.dart';
import '../intro/tutos/tuto_scene_card.dart';
import '../studio/artist_marketplace.dart';

/// Tableau de bord admin unique (fusion de l'ancien « Tableau de bord » et de l'« ADMIN HUB » / AppData).
/// Les données se chargent à l'ouverture de la page et via le bouton « Actualiser » uniquement,
/// pas au retour d'une sous-page.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _forcingReward = false;
  bool _loading = true;

  // Statistiques
  int _totalUsers = 0;
  int _newUsersToday = 0;
  int _officialPending = 0;
  int _influencerPending = 0;
  int _activeWeek = 0;
  int _moderationPending = 0;
  int _boostsPending = 0;
  int _stickersPending = 0;
  int _retraitsPending = 0;
  // Connexions par plateforme : [total, aujourd'hui, 7 jours, 30 jours, 3 mois]
  Map<String, dynamic>? _stats; // réponse de GET /admin/stats
  int _coinsDeposit = 0, _coinsEarned = 0, _xofDeposit = 0, _xofPayout = 0, _postsTotal = 0, _suspended = 0;

  @override
  void initState() {
    super.initState();
    _loadStats(showBoostAlert: true);
    _loadPlatformStats();
  }

  /// Statistiques par plateforme : non fournies par l'API pour le moment (voir lacunes_api_regie_admin.md).
  Future<void> _loadPlatformStats() async {
    if (!mounted) return;
  }

  Future<void> _loadStats({bool showBoostAlert = false}) async {
    setState(() => _loading = true);
    try {
      final st = await RegieApi.getMap('/admin/stats');
      if (!mounted) return;
      Map<String, dynamic> sub(String k) => st[k] is Map ? Map<String, dynamic>.from(st[k] as Map) : <String, dynamic>{};
      final users = sub('users');
      final content = sub('content');
      final money = sub('money');
      final pending = sub('pending');
      int n(Object? v) => v is num ? v.toInt() : 0;
      final perDay = users['signups_per_day'] is Map ? Map<String, dynamic>.from(users['signups_per_day'] as Map) : <String, dynamic>{};
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      setState(() {
        _stats = st;
        _totalUsers = n(users['total']);
        _newUsersToday = n(perDay[today]);
        _activeWeek = n(users['active_7d']);
        _suspended = n(users['suspended']);
        _postsTotal = n(content['posts_total']);
        _moderationPending = n(pending['moderation_posts']);
        _boostsPending = n(pending['ads']);
        _stickersPending = n(pending['sticker_packs']);
        _retraitsPending = n(pending['withdrawals']);
        _officialPending = n(pending['official_accounts']);
        _influencerPending = n(pending['influencer_requests']);
        _coinsDeposit = n(money['coins_deposit']);
        _coinsEarned = n(money['coins_earned']);
        _xofDeposit = n(money['xof_deposit']);
        _xofPayout = n(money['xof_payout']);
        _loading = false;
      });
      if (showBoostAlert && _boostsPending > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showPendingBoostModal(_boostsPending));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chargement impossible : ${RegieApi.err(e)}')));
    }
  }

  // Navigation simple : pas de rechargement au retour (demande du propriétaire)
  void _push(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final me = context.read<UserAuthProvider>().loginUserData;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: colors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Tableau de bord admin',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: colors.textPrimary, size: 22),
            onPressed: _loading ? null : () { _loadStats(); _loadPlatformStats(); },
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _loading && _stats == null
          ? Center(child: CircularProgressIndicator(color: colors.primary))
          : RefreshIndicator(
              onRefresh: () => _loadStats(),
              color: colors.primary,
              child: CenteredContent(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    if (_loading) const LinearProgressIndicator(minHeight: 2),
                    _AdminHeader(me: me, colors: colors),
                    const SizedBox(height: 16),
                    _buildTodo(colors),
                    const SizedBox(height: 20),
                    _SectionLabel('Accès rapides', colors),
                    const SizedBox(height: 8),
                    _buildQuickAccess(colors),
                    const SizedBox(height: 20),
                    _SectionLabel("Finances de l'app", colors),
                    const SizedBox(height: 8),
                    _buildFinances(colors),
                    const SizedBox(height: 20),
                    _SectionLabel('Retraits', colors),
                    const SizedBox(height: 8),
                    _buildRetraits(colors),
                    const SizedBox(height: 20),
                    _SectionLabel('Activité', colors),
                    const SizedBox(height: 8),
                    _buildActivity(colors),
                    const SizedBox(height: 20),
                    _SectionLabel('Modules', colors),
                    const SizedBox(height: 8),
                    _buildModules(colors),
                    const SizedBox(height: 20),
                    _SectionLabel('Actions', colors),
                    const SizedBox(height: 8),
                    _AdminActionCard(
                      icon: Icons.emoji_events_rounded,
                      iconColor: colors.supportAccent,
                      label: 'Forcer le classement commentateurs',
                      desc: 'Recalcule et récompense le Top 5 de la semaine précédente',
                      loading: _forcingReward,
                      onTap: _forceWeeklyCommentatorsReward,
                      colors: colors,
                      trailing: TextButton.icon(
                        onPressed: () => _push(const WeeklyTopCommentatorsPage()),
                        icon: const Icon(Icons.leaderboard_rounded, size: 16),
                        label: const Text('Voir le classement'),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.supportAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── À traiter ──────────────────────────────────────────────────────────────

  Widget _buildTodo(AppColors c) {
    final items = <_TodoItem>[
      _TodoItem(Icons.gavel_rounded, 'Signalements à modérer', _moderationPending, c.danger,
          () => _push(const ModerationReportsPage())),
      _TodoItem(Icons.north_east_rounded, 'Retraits en attente', _retraitsPending, c.warning,
          () => _push(AdminRetraitListPage())),
      _TodoItem(Icons.campaign_rounded, 'Boosts / publicités à valider', _boostsPending, const Color(0xFF8E3CC4),
          () => _push(const AdvertisementManagementPage())),
      _TodoItem(Icons.verified_rounded, 'Comptes officiels à traiter', _officialPending, c.info,
          () => _push(const OfficialAccountsPage())),
      _TodoItem(Icons.star_rounded, 'Demandes influenceur', _influencerPending, c.supportAccent,
          () => _push(const InfluencerRequestsPage())),
    ].where((i) => i.count > 0).toList();

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _box(c),
        child: Row(children: [
          Icon(Icons.check_circle_rounded, color: c.success, size: 20),
          const SizedBox(width: 10),
          Text('Rien à traiter pour le moment', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
        ]),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _box(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text('À TRAITER',
                style: TextStyle(color: c.danger, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 0.5, indent: 48, color: c.border),
            InkWell(
              onTap: items[i].onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  Icon(items[i].icon, color: items[i].color, size: 20),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(items[i].label,
                        style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                  _Badge(items[i].count, items[i].color),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 20),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Accès rapides ──────────────────────────────────────────────────────────

  Widget _buildQuickAccess(AppColors c) {
    final tiles = [
      _QuickTile(Icons.people_alt_rounded, 'Utilisateurs', 'Recherche & gestion', c.info, 0,
          () => _push(UserSearchPage())),
      _QuickTile(Icons.receipt_long_rounded, 'Transactions', 'Tous les utilisateurs', c.primary, 0,
          () => _push(TransactionsListPage())),
      _QuickTile(Icons.account_balance_rounded, 'Retraits', 'Demandes de retrait', c.warning, _retraitsPending,
          () => _push(AdminRetraitListPage())),
      _QuickTile(Icons.gavel_rounded, 'Modération', 'Signalements, blocages', c.danger, _moderationPending,
          () => _push(const ModerationReportsPage())),
      _QuickTile(Icons.verified_rounded, 'Certifications', 'Ajouter ou retirer un badge', c.info, 0,
          () => _push(const CertificationsAdminPage())),
      _QuickTile(Icons.live_tv_rounded, 'Vente en direct', 'Commandes, litiges, stocks', c.warning, 0,
          () => _push(const LiveShopAdminPage())),
      _QuickTile(Icons.badge_rounded, 'Identités vendeurs', 'Vérifier les pièces', c.info, 0,
          () => _push(const SellerVerificationsAdminPage())),
      _QuickTile(Icons.system_update_rounded, "Version de l'application", 'Mise à jour obligatoire ou non', c.warning, 0,
          () => _push(const AppVersionAdminPage())),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: [for (final t in tiles) _QuickTileCard(tile: t, colors: c)],
    );
  }

  // ── Finances (ex-AppData) ──────────────────────────────────────────────────

  Widget _buildFinances(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: _box(c),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _metric(c, 'Pièces de dépôt', '${_int(_coinsDeposit)} pièces', Icons.toll_rounded, c.primary)),
            Expanded(child: _metric(c, 'Pièces gagnées', '${_int(_coinsEarned)} pièces', Icons.toll_rounded, c.warning)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _metric(c, 'Solde de dépôt', _money(_xofDeposit.toDouble()), Icons.account_balance_wallet_rounded, c.info)),
            Expanded(child: _metric(c, 'Solde de retrait', _money(_xofPayout.toDouble()), Icons.north_east_rounded, c.textSecondary)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _push(const CommissionsAdminPage()),
              icon: const Icon(Icons.pie_chart_rounded, size: 18),
              label: const Text('Voir les commissions'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                side: BorderSide(color: c.primary.withOpacity(0.5)),
                minimumSize: const Size(0, 38),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Retraits ───────────────────────────────────────────────────────────────

  Widget _buildRetraits(AppColors c) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _push(AdminRetraitListPage()),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: _box(c),
        child: Row(children: [
          Expanded(child: _counter(c, 'En attente', _retraitsPending, c.warning)),
          Icon(Icons.chevron_right_rounded, color: c.textSecondary),
        ]),
      ),
    );
  }

  // ── Activité ───────────────────────────────────────────────────────────────

  Widget _buildActivity(AppColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: _box(c),
      child: Column(children: [
        Row(children: [
          Expanded(child: _metric(c, 'Utilisateurs', _int(_totalUsers), Icons.people_rounded, c.primary,
              sub: '+$_newUsersToday aujourd\'hui')),
          Expanded(child: _metric(c, 'Publications', _int(_postsTotal), Icons.article_rounded, c.info)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _metric(c, 'Actifs sur 7 jours', _int(_activeWeek), Icons.bolt_rounded, c.primary)),
          Expanded(child: _metric(c, 'Comptes suspendus', _int(_suspended), Icons.block_rounded, c.danger)),
        ]),
        const SizedBox(height: 12),
        Divider(height: 24, color: c.border),
        Row(children: [
          Text('Connexions', style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (final e in const [('today', "Aujourd'hui"), ('yesterday', 'Hier'), ('d7', '7 jours'), ('d30', '30 jours'), ('d90', '90 jours')])
            Expanded(child: _connCounter(c, e.$2, e.$1)),
        ]),
        const SizedBox(height: 6),
        Text('Personnes différentes actives (A = Android, i = iPhone). Historique tenu depuis le 02/11/2026.', style: TextStyle(color: c.textSecondary, fontSize: 10)),
      ]),
    );
  }

  // ── Modules ────────────────────────────────────────────────────────────────

  Widget _buildModules(AppColors c) {
    final modules = [
      _Module(Icons.verified_rounded, 'Comptes officiels', c.info, _officialPending, const OfficialAccountsPage()),
      _Module(Icons.star_rounded, 'Influenceurs', c.supportAccent, _influencerPending, const InfluencerRequestsPage()),
      _Module(Icons.campaign_rounded, 'Publicités', const Color(0xFF8E3CC4), _boostsPending, const AdvertisementManagementPage()),
      _Module(Icons.public_rounded, 'Régie : annonceurs, diffuseurs et partageurs', c.info, 0, const AdsRegieAdminPage()),
      _Module(Icons.insights_rounded, 'Suivi de la page Travail', c.primary, 0, const WorkStatsPage()),
      _Module(Icons.mark_email_read_rounded, 'Suivi des e-mails', c.info, 0, const EmailsAdminPage()),
      _Module(Icons.groups_rounded, 'Groupes officiels', c.info, 0, const AfrolookGroupMigrationPage()),
      _Module(Icons.ondemand_video_rounded, 'Pub AdMob', const Color(0xFF8E3CC4), 0, AdAdminPage()),
      _Module(Icons.quiz_rounded, 'Quiz', const Color(0xFFE0A100), 0, const QuizAdminPage()),
      _Module(Icons.school_rounded, 'Étude', const Color(0xFF1FAA59), 0, const EtudeAdminPage()),
      _Module(Icons.auto_stories_rounded, 'Contes', const Color(0xFFB07A1F), 0, const ContesAdminPage()),
      _Module(Icons.newspaper_rounded, 'Actualités', c.info, 0, const NewsAdminPage()),
      _Module(Icons.pie_chart_rounded, 'Commissions', c.primary, 0, const CommissionsAdminPage()),
      _Module(Icons.account_balance_wallet_rounded, 'Rémunération', c.primary, 0, RemunerationAdminPage()),
      _Module(Icons.storefront_rounded, 'Contenus payants', c.supportAccent, 0, const AdminContentPage()),
      _Module(Icons.mail_rounded, 'Emailing', c.textSecondary, 0, AdminEmailScreen()),
      _Module(Icons.payment_rounded, 'Moyens de paiement', c.primary, 0, const PaymentMethodsAdminPage()),
      _Module(Icons.monitor_heart_rounded, 'Suivi des paiements', c.danger, 0, const PaymentLogsAdminPage()),
      _Module(Icons.school_rounded, 'Tutoriels', c.supportAccent, 0, const TutoListPage(showAll: true)),
      _Module(Icons.live_tv_rounded, 'Canaux', c.info, 0, const AdminCanauxPage()),
      _Module(Icons.groups_rounded, 'Groupes', c.danger, 0, const AdminGroupsPage()),
      _Module(Icons.emoji_emotions_rounded, 'Stickers', c.warning, _stickersPending, const AdminStickersPage()),
      _Module(Icons.library_music_rounded, 'Sons artistes', const Color(0xFF9B59B6), 0, const AdminArtistSoundsPage()),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.05,
      children: [for (final m in modules) _ModuleCard(module: m, colors: c, onTap: () => _push(m.page))],
    );
  }

  // ── Petits éléments ────────────────────────────────────────────────────────

  BoxDecoration _box(AppColors c) => BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      );

  Widget _metric(AppColors c, String label, String value, IconData icon, Color color, {String? sub}) {
    return Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: color.withOpacity(c.isDark ? 0.18 : 0.12), borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
          Text(sub == null ? label : '$label · $sub',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontSize: 11)),
        ]),
      ),
    ]);
  }

  /// Connexions d'une période : total, puis Android (A) et iPhone (i).
  Widget _connCounter(AppColors c, String label, String key) {
    final conn = _stats?['connections'] is Map ? Map<String, dynamic>.from(_stats!['connections'] as Map) : const <String, dynamic>{};
    final v = conn[key] is Map ? Map<String, dynamic>.from(conn[key] as Map) : const <String, dynamic>{};
    int n(Object? x) => x is num ? x.toInt() : 0;
    return Column(children: [
      _counter(c, label, n(v['all']), c.info),
      Text('A ${n(v['android'])} · i ${n(v['ios'])}', style: TextStyle(color: c.textSecondary, fontSize: 9.5)),
    ]);
  }

  Widget _counter(AppColors c, String label, int value, Color color) => Column(children: [
        Text(_int(value),
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 10.5)),
      ]);
  static final NumberFormat _moneyFmt = NumberFormat('#,##0', 'fr');
  static final NumberFormat _intFmt = NumberFormat.decimalPattern('fr');
  String _int(int v) => _intFmt.format(v);
  String _money(double v) => '${_moneyFmt.format(v)} FCFA';

  // ── Boosts en attente (alerte à l'ouverture) ───────────────────────────────

  void _showPendingBoostModal(int count) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Boosts en attente',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text(
            '$count demande${count > 1 ? 's' : ''} de boost en attente de validation. '
            'Les utilisateurs attendent une activation sous 24 h.',
            style: TextStyle(color: colors.textSecondary, fontSize: 14, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Plus tard', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _push(const AdvertisementManagementPage());
              },
              style: FilledButton.styleFrom(backgroundColor: colors.danger, foregroundColor: Colors.white),
              child: Text('Voir les boosts ($count)'),
            ),
          ],
        );
      },
    );
  }


  // ── Classement commentateurs ───────────────────────────────────────────────

  Future<void> _forceWeeklyCommentatorsReward() async {
    if (_forcingReward) return;
    final colors = AppColors.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Lancer le classement commentateurs', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'Cela calcule le Top Commentateurs de la semaine précédente et verse les récompenses prévues. '
          'Un classement déjà payé ne l\'est jamais deux fois.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Confirmer', style: TextStyle(color: colors.info))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _forcingReward = true);
    try {
      final r = await RegieApi.post('/admin/weekly/recompute', body: {'kind': 'commentators', 'pay': true});
      final data = (r is Map && r['data'] is Map) ? Map<String, dynamic>.from(r['data'] as Map) : <String, dynamic>{};
      if (!mounted) return;
      final ranked = (data['ranked'] as num?)?.toInt() ?? 0;
      final paid = (data['paid'] as num?)?.toInt() ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ranked == 0 ? 'Aucun commentaire éligible pour la semaine.' : 'Terminé : $ranked classé(s), $paid récompensé(s).'),
          backgroundColor: paid > 0 ? colors.success : colors.warning,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : ${RegieApi.err(e)}'), backgroundColor: colors.danger));
    } finally {
      if (mounted) setState(() => _forcingReward = false);
    }
  }
}

// ── Composants ───────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  final dynamic me;
  final AppColors colors;
  const _AdminHeader({required this.me, required this.colors});

  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greet = h < 12 ? 'Bonjour' : (h < 18 ? 'Bon après-midi' : 'Bonsoir');
    return Row(children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.primary.withOpacity(colors.isDark ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.admin_panel_settings_rounded, color: colors.primary, size: 24),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$greet, @${me?.pseudo ?? 'admin'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          Text(DateFormat('EEEE d MMMM yyyy', 'fr').format(DateTime.now()),
              style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        ]),
      ),
    ]);
  }
}

class _TodoItem {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;
  const _TodoItem(this.icon, this.label, this.count, this.color, this.onTap);
}

class _QuickTile {
  final IconData icon;
  final String label, sub;
  final Color color;
  final int badge;
  final VoidCallback onTap;
  const _QuickTile(this.icon, this.label, this.sub, this.color, this.badge, this.onTap);
}

class _QuickTileCard extends StatelessWidget {
  final _QuickTile tile;
  final AppColors colors;
  const _QuickTileCard({required this.tile, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: tile.color.withOpacity(c.isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tile.icon, color: tile.color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tile.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text(tile.sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            if (tile.badge > 0) _Badge(tile.badge, tile.color),
          ]),
        ),
      ),
    );
  }
}

class _Module {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final Widget page;
  const _Module(this.icon, this.label, this.color, this.badge, this.page);
}

class _ModuleCard extends StatelessWidget {
  final _Module module;
  final AppColors colors;
  final VoidCallback onTap;
  const _ModuleCard({required this.module, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Stack(children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: module.color.withOpacity(c.isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(module.icon, color: module.color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(module.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.2)),
              ],
            ),
            if (module.badge > 0) Positioned(top: 0, right: 0, child: _Badge(module.badge, c.danger)),
          ]),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  const _Badge(this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.16), borderRadius: BorderRadius.circular(20)),
        child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
      );
}


class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label, desc;
  final bool loading;
  final VoidCallback onTap;
  final AppColors colors;
  final Widget? trailing;

  const _AdminActionCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.desc,
    required this.loading,
    required this.onTap,
    required this.colors,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(colors.isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(color: colors.textSecondary, fontSize: 11, height: 1.3)),
              ]),
            ),
            const SizedBox(width: 10),
            loading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colors.info))
                : OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.info,
                      side: BorderSide(color: colors.info.withOpacity(0.5)),
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Lancer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
          ]),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _SectionLabel(this.text, this.colors);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(text.toUpperCase(),
            style: TextStyle(color: colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      );
}
